module.exports = async ({ github, context }) => {
  const fs = require('fs');
  const config = JSON.parse(fs.readFileSync('.github/cleanup-config.json', 'utf8'));

  // Get workflow ID -> name mapping
  const workflows = await github.paginate(
    github.rest.actions.listRepoWorkflows,
    {
      owner: context.repo.owner,
      repo: context.repo.repo
    }
  );

  const workflowNames = new Map();
  for (const wf of workflows) {
    workflowNames.set(wf.id, wf.name);
  }

  const runs = await github.paginate(
    github.rest.actions.listWorkflowRunsForRepo,
    {
      owner: context.repo.owner,
      repo: context.repo.repo,
      per_page: 100
    }
  );

  // Group runs by workflow name (using workflow_id)
  const groupedRuns = {};
  for (const run of runs) {
    const workflowName = workflowNames.get(run.workflow_id);
    if (!workflowName) continue;
    if (!groupedRuns[workflowName]) groupedRuns[workflowName] = [];
    groupedRuns[workflowName].push(run);
  }

  // Clean up each workflow
  let deleteCount = 0;
  for (const [name, workflowRuns] of Object.entries(groupedRuns)) {
    workflowRuns.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    const keepCount = config.workflows[name] ?? config.defaultKeep;
    const toDelete = workflowRuns.slice(keepCount);

    for (const run of toDelete) {
      console.log(`Deleting: #${run.id} (${run.name}) - ${run.created_at}`);
      await github.rest.actions.deleteWorkflowRun({
        owner: context.repo.owner,
        repo: context.repo.repo,
        run_id: run.id
      });
      deleteCount++;
    }
  }

  console.log(`Total: ${runs.length}, Deleted: ${deleteCount}`);
};
