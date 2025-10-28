import React, { useEffect, useState } from "react";

function ProductSyncPoller({
  storeUid,
  initialProductCount,
  displayMode = "toast",
}) {
  const [isPolling, setIsPolling] = useState(false);
  const [elapsedTime, setElapsedTime] = useState(0);

  useEffect(() => {
    // Only start polling if there are no products initially
    if (initialProductCount === 0) {
      // Check URL params to see if we just started a sync
      const urlParams = new URLSearchParams(window.location.search);
      const fromSync = urlParams.get("from_sync") === "true";

      if (fromSync) {
        setIsPolling(true);
      }
    }
  }, [initialProductCount]);

  useEffect(() => {
    if (!isPolling) return;

    let pollInterval;
    let timeInterval;

    const checkForProducts = async () => {
      try {
        const response = await fetch(
          `/connections/stores/${storeUid}/check_products`,
          {
            headers: {
              "X-Requested-With": "XMLHttpRequest",
              Accept: "application/json",
            },
          }
        );

        if (response.ok) {
          const data = await response.json();

          if (data.products_count > 0) {
            // Products found! Reload the page
            window.location.reload();
          }
        }
      } catch (error) {
        console.error("Error checking for products:", error);
      }
    };

    // Poll every 5 seconds
    pollInterval = setInterval(checkForProducts, 6000);

    // Update elapsed time every second for UI
    timeInterval = setInterval(() => {
      setElapsedTime((prev) => prev + 1);
    }, 1000);

    // Stop polling after 2 minutes (safety measure)
    const timeout = setTimeout(() => {
      setIsPolling(false);
    }, 120000);

    return () => {
      clearInterval(pollInterval);
      clearInterval(timeInterval);
      clearTimeout(timeout);
    };
  }, [isPolling, storeUid]);

  if (!isPolling) return null;

  // Inline display for empty state
  if (displayMode === "inline") {
    return (
      <div className="bg-white border border-slate-200 rounded-lg p-12 text-center">
        <div className="w-16 h-16 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
          <svg
            className="animate-spin h-8 w-8 text-blue-600"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            ></circle>
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            ></path>
          </svg>
        </div>
        <h3 className="text-lg font-semibold text-slate-900 mb-2">
          Syncing your products...
        </h3>
        <p className="text-sm text-slate-600 mb-4">
          We're fetching your products from Shopify.
          <br />
          We'll refresh the page automatically when some are ready.
        </p>
        <div className="inline-flex items-center space-x-2 text-sm text-slate-500">
          <svg
            className="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span>Elapsed: {elapsedTime}s</span>
        </div>
      </div>
    );
  }

  // Toast notification display
  return (
    <div className="fixed bottom-4 right-4 z-40 bg-white border border-slate-200 rounded-lg shadow-lg p-4 max-w-sm">
      <div className="flex items-start space-x-3">
        {/* Spinner */}
        <div className="flex-shrink-0">
          <svg
            className="animate-spin h-5 w-5 text-blue-600"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            ></circle>
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            ></path>
          </svg>
        </div>

        {/* Content */}
        <div className="flex-1">
          <h4 className="text-sm font-semibold text-slate-900 mb-1">
            Syncing products...
          </h4>
          <p className="text-xs text-slate-600">
            This may take a minute. We'll refresh the page when products are
            ready.
          </p>
          <p className="text-xs text-slate-500 mt-2">Elapsed: {elapsedTime}s</p>
        </div>

        {/* Close button */}
        <button
          onClick={() => setIsPolling(false)}
          className="flex-shrink-0 text-slate-400 hover:text-slate-600"
          aria-label="Stop polling"
        >
          <svg
            className="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>
    </div>
  );
}

export default ProductSyncPoller;
