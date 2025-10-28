import React from "react";
import { SvgIcon } from "../components";

function WelcomeModal({ isOpen, storeName, storeUid }) {
  if (!isOpen) return null;

  const handleClose = () => {
    // Remove the welcome parameter from the URL
    const url = new URL(window.location);
    url.searchParams.delete("welcome");
    window.history.replaceState({}, "", url);
    // Force a re-render by navigating to the clean URL
    window.location.href = url.toString();
  };

  const handleStartSync = () => {
    // Redirect to the sync products endpoint
    // The sync_products action will redirect back with from_sync=true to trigger polling
    window.location.href = `/connections/stores/${storeUid}/sync_products`;
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      onClick={(e) => {
        if (e.target === e.currentTarget) handleClose();
      }}
    >
      <div
        className="relative w-full max-w-md bg-white rounded-lg shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close button */}
        <button
          onClick={handleClose}
          className="absolute top-4 right-4 text-slate-400 hover:text-slate-600 transition-colors"
          aria-label="Close"
        >
          <SvgIcon name="XIcon" className="w-5 h-5" />
        </button>

        {/* Content */}
        <div className="p-6">
          {/* Success Icon */}
          <div className="flex justify-center mb-4">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
              <svg
                className="w-8 h-8 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>
          </div>

          {/* Title */}
          <h2 className="text-2xl font-bold text-slate-900 text-center mb-2">
            Your Shopify store is now connected
          </h2>

          {/* Store name */}
          <p className="text-center text-slate-600 mb-4">
            Next up, let's sync your products
          </p>

          {/* Actions */}
          <div className="flex flex-col space-y-2 mt-6">
            <button
              onClick={handleStartSync}
              className="w-full bg-slate-900 text-white hover:bg-slate-800 px-4 py-3 rounded-md font-medium transition-colors flex items-center justify-center space-x-2"
            >
              <SvgIcon name="RefreshIcon" className="w-5 h-5" />
              <span>Start Product Sync</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default WelcomeModal;
