import React, { useState } from "react";

function SyncVariantMockupsModal({ isOpen, onClose, variantMappingsCount, syncUrl, storePlatform }) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const estimatedSeconds = variantMappingsCount * 10;
  const estimatedMinutes = Math.ceil(estimatedSeconds / 60);

  const handleConfirm = () => {
    setIsSubmitting(true);
    // Navigate to the sync URL (Rails will handle the sync and redirect)
    window.location.href = syncUrl;
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black opacity-50 transition-opacity"
        onClick={!isSubmitting ? onClose : undefined}
      ></div>

      {/* Modal */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="relative bg-white rounded-xl shadow-2xl max-w-md w-full"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Close button */}
          <button
            type="button"
            onClick={onClose}
            disabled={isSubmitting}
            className="absolute top-4 right-4 text-slate-400 hover:text-slate-600 transition-colors disabled:opacity-50"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>

          {/* Content */}
          <div className="p-6">
            {/* Title */}
            <h3 className="text-lg font-semibold text-slate-900 mb-4 pr-8">
              Sync mockup images
            </h3>

            {/* Description */}
            <div className="space-y-3 text-sm text-slate-600 mb-6">
              <div className="flex items-start">
                <span className="mr-2">•</span>
                <span>
                  This action will batch upload {variantMappingsCount} variant image{variantMappingsCount !== 1 ? 's' : ''} to your {storePlatform} store.
                </span>
              </div>
              <div className="flex items-start">
                <span className="mr-2">•</span>
                <span>
                  Note this takes around 10 seconds per product so you'll want to confirm the uploads are in your store in about {estimatedMinutes} minute{estimatedMinutes !== 1 ? 's' : ''}.
                </span>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex justify-end space-x-3">
              <button
                type="button"
                onClick={onClose}
                disabled={isSubmitting}
                className="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-md hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirm}
                disabled={isSubmitting}
                className="px-4 py-2 text-sm font-medium text-white bg-slate-900 rounded-md hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center"
              >
                {isSubmitting ? (
                  <>
                    <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                    Syncing...
                  </>
                ) : (
                  "Continue with sync"
                )}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default SyncVariantMockupsModal;

