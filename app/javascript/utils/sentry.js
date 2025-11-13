// Sentry frontend error tracking
// https://docs.sentry.io/platforms/javascript/

import * as Sentry from "@sentry/browser";

// Initialize Sentry only if DSN is configured
const sentryDsn = document.querySelector('meta[name="sentry-dsn"]')?.content;

if (sentryDsn) {
  Sentry.init({
    dsn: sentryDsn,
    
    // Set the environment (production, staging, development)
    environment: document.querySelector('meta[name="rails-env"]')?.content || 'development',
    
    // Set release version to track which version has bugs
    release: document.querySelector('meta[name="app-version"]')?.content,
    
    // Tracing sample rate (0.0 to 1.0)
    // This determines the percentage of transactions sent to Sentry
    tracesSampleRate: parseFloat(document.querySelector('meta[name="sentry-traces-sample-rate"]')?.content || '0.1'),
    
    // Capture unhandled promise rejections
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.replayIntegration({
        // Capture 10% of all sessions for replay
        sessionSampleRate: 0.1,
        // Capture 100% of sessions with errors for replay
        errorSampleRate: 1.0,
      }),
    ],
    
    // Don't send errors from localhost/development
    beforeSend(event, hint) {
      // Don't send events in development unless explicitly enabled
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        return null;
      }
      return event;
    },
    
    // Filter out certain errors that aren't actionable
    ignoreErrors: [
      // Browser extension errors
      'Non-Error promise rejection captured',
      'ResizeObserver loop limit exceeded',
      // Network errors
      'NetworkError',
      'Network request failed',
      // Script loading errors from browser extensions
      /^Loading chunk \d+ failed/,
    ],
  });

  // Set user context if available
  const userEmail = document.querySelector('meta[name="current-user-email"]')?.content;
  const userId = document.querySelector('meta[name="current-user-id"]')?.content;
  
  if (userEmail && userId) {
    Sentry.setUser({
      id: userId,
      email: userEmail,
    });
  }

  // Add custom context
  const subdomain = document.querySelector('meta[name="subdomain"]')?.content;
  if (subdomain) {
    Sentry.setTag('subdomain', subdomain);
  }
  
  console.log('Sentry initialized for frontend error tracking');
}

// Export Sentry for manual error reporting if needed
export default Sentry;

