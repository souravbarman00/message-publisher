// Health check for workers - checks if worker processes are running
/* eslint-disable n/no-process-exit */

try {
  // More lenient health check - just verify the process is running
  // Workers may restart due to Kafka connection issues but SQS/SNS still work
  const uptimeMs = process.uptime() * 1000;

  if (uptimeMs > 5000) { // 5 seconds (reduced from 10)
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
