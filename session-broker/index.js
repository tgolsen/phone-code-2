const { ECSClient, RunTaskCommand, DescribeTasksCommand, StopTaskCommand } = require('@aws-sdk/client-ecs');
const { EC2Client, DescribeNetworkInterfacesCommand } = require('@aws-sdk/client-ec2');

const ecs = new ECSClient();

const CLUSTER = process.env.ECS_CLUSTER || 'phone-code';
const TASK_DEFINITION = process.env.ECS_TASK_DEFINITION || 'phone-code-session';
const SUBNETS = (process.env.SUBNETS || '').split(',').filter(Boolean);
const SECURITY_GROUP = process.env.SECURITY_GROUP || '';
const ASSIGN_PUBLIC_IP = process.env.ASSIGN_PUBLIC_IP !== 'false';
const API_KEY = process.env.API_KEY || '';

function response(statusCode, body) {
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    };
}

function validateAuth(event) {
    const provided = event.headers?.['x-api-key'] || event.headers?.['X-API-Key'] || '';
    if (!API_KEY) return true; // no key configured — skip validation
    return provided === API_KEY;
}

async function runTask(pubkey, project, githubUser, githubToken) {
    const overrides = {
        containerOverrides: [
            {
                name: TASK_DEFINITION,
                environment: [
                    { name: 'PUBKEY', value: pubkey },
                    { name: 'PROJECT', value: project },
                    { name: 'GITHUB_USER', value: githubUser },
                    { name: 'GITHUB_TOKEN', value: githubToken || '' },
                ],
            },
        ],
    };

    const networkConfig = {};
    if (SUBNETS.length) networkConfig.subnets = SUBNETS;
    if (SECURITY_GROUP) networkConfig.securityGroups = [SECURITY_GROUP];
    if (Object.keys(networkConfig).length) {
        networkConfig.assignPublicIp = ASSIGN_PUBLIC_IP ? 'ENABLED' : 'DISABLED';
    }

    const cmd = new RunTaskCommand({
        cluster: CLUSTER,
        taskDefinition: TASK_DEFINITION,
        launchType: 'FARGATE',
        overrides,
        networkConfiguration: Object.keys(networkConfig).length
            ? { awsvpcConfiguration: networkConfig }
            : undefined,
    });

    const result = await ecs.send(cmd);

    if (!result.tasks || result.tasks.length === 0) {
        throw new Error('No tasks launched');
    }

    const taskArn = result.tasks[0].taskArn;
    return taskArn;
}

async function waitForRunning(taskArn, maxWait = 120000) {
    const start = Date.now();
    while (Date.now() - start < maxWait) {
        const cmd = new DescribeTasksCommand({
            cluster: CLUSTER,
            tasks: [taskArn],
        });
        const result = await ecs.send(cmd);
        const task = result.tasks?.[0];

        if (!task) throw new Error('Task not found');

        if (task.lastStatus === 'RUNNING') {
            const eni = task.attachments?.[0]?.details?.find((d) => d.name === 'networkInterfaceId');
            // Public IP may not be immediately available — retry a few more seconds
            return task;
        }

        if (task.lastStatus === 'STOPPED') {
            const reason = task.stoppedReason || 'Unknown';
            throw new Error(`Task stopped: ${reason}`);
        }

        await new Promise((r) => setTimeout(r, 2000));
    }
    throw new Error('Timed out waiting for task to start');
}

async function stopTask(taskId) {
    const cmd = new StopTaskCommand({
        cluster: CLUSTER,
        task: taskId,
        reason: 'Phone Code session ended',
    });
    await ecs.send(cmd);
}

async function getTaskConnectionInfo(taskId) {
    const result = await ecs.send(
        new DescribeTasksCommand({ cluster: CLUSTER, tasks: [taskId] })
    );
    const task = result.tasks?.[0];
    if (!task) return null;

    const eniId = task.attachments?.[0]?.details?.find(
        (d) => d.name === 'networkInterfaceId'
    )?.value;

    if (!eniId) return { taskId, host: 'pending', status: task.lastStatus };

    try {
        const ec2client = new EC2Client();
        const eniResult = await ec2client.send(
            new DescribeNetworkInterfacesCommand({ NetworkInterfaceIds: [eniId] })
        );
        const eni = eniResult.NetworkInterfaces?.[0];
        const host = eni?.Association?.PublicIp || eni?.PrivateIpAddress || 'pending';
        return { taskId, host, status: task.lastStatus, port: 2222 };
    } catch {
        return { taskId, host: 'resolving', status: task.lastStatus };
    }
}

exports.handler = async (event) => {
    if (!validateAuth(event)) {
        return response(401, { error: 'Unauthorized' });
    }

    const method = event.httpMethod || event.requestContext?.http?.method || '';
    const path = event.path || event.rawPath || '';
    const taskId = event.queryStringParameters?.taskId || decodeURIComponent(path.split('/sessions/')[1] || '');

    // DELETE /sessions/{taskId} — stop session
    if (method === 'DELETE' && taskId) {
        try {
            await stopTask(taskId);
            return response(200, { status: 'stopped', taskId });
        } catch (err) {
            return response(500, { error: err.message });
        }
    }

    // GET /sessions/{taskId} — poll connection info
    if (method === 'GET' && taskId) {
        try {
            const info = await getTaskConnectionInfo(taskId);
            if (!info) return response(404, { error: 'Task not found' });
            return response(200, info);
        } catch (err) {
            return response(500, { error: err.message });
        }
    }

    // POST /sessions — create session (async: returns immediately, client polls GET)
    if (method === 'POST') {
        let body;
        try {
            body = JSON.parse(event.body || '{}');
        } catch {
            return response(400, { error: 'Invalid JSON' });
        }

        const { project, pubkey, github_user, github_token } = body;
        if (!project) return response(400, { error: 'project required' });
        if (!pubkey) return response(400, { error: 'pubkey required' });

        try {
            const taskArn = await runTask(
                pubkey,
                project,
                github_user || process.env.DEFAULT_GITHUB_USER || '',
                github_token || process.env.DEFAULT_GITHUB_TOKEN || ''
            );

            return response(202, {
                task_arn: taskArn,
                host: 'pending',
                status: 'launching',
                message: 'Task started. Poll GET /sessions/{task_arn} for connection info.',
            });
        } catch (err) {
            return response(500, { error: err.message });
        }
    }

    return response(404, { error: 'Not found' });
};
