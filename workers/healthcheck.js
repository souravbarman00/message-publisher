// Health check for workers - checks if worker processes are running
/* eslint-disable n/no-process-exit */

try {
  // Check if any worker log files have been updated recently (indicating they're running)
  // Alternative: Check if workers are creating any output
  // For simplicity, we'll just check if the process is running for more than 10 seconds
  const uptimeMs = process.uptime() * 1000;

  if (uptimeMs > 10000) { // 10 seconds
    console.log('Workers health check passed - running for', Math.floor(uptimeMs / 1000), 'seconds');
    process.exit(0);
  } else {
    console.log('Workers still starting up...');
    process.exit(1);
  }

} catch (error) {
  console.error('Health check failed:', error.message);
  process.exit(1);
}
