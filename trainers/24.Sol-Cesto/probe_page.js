// Page-side reconnaissance: is the game loaded, and can we reach the runtime?
JSON.stringify({
  ready: document.readyState,
  title: document.title,
  hidden: document.hidden,
  canvasCount: document.querySelectorAll('canvas').length,
  bodyLen: document.body ? document.body.innerHTML.length : -1,
  useWorker: c3_runtimeInterface._useWorker,
  hasWorker: !!c3_runtimeInterface._worker,
  localRuntime: c3_runtimeInterface._localRuntime === null ? 'null' : typeof c3_runtimeInterface._localRuntime,
  // Construct posts messages to the runtime through this port; if the runtime
  // is alive the port exists and the job scheduler will have workers.
  hasPort: !!c3_runtimeInterface._messageChannelPort,
  jobScheduler: (() => {
    try {
      const js = c3_runtimeInterface._jobScheduler;
      if (!js) return 'none';
      return {
        keys: Object.keys(js).slice(0, 20),
        workerCount: js._workers ? js._workers.length : undefined,
        maxWorkers: js._maxWorkers,
      };
    } catch (e) { return 'err: ' + e; }
  })(),
  domHandlers: (() => {
    try { return Object.keys(c3_runtimeInterface._domHandlers || {}).slice(0, 40); }
    catch (e) { return 'err'; }
  })(),
})
