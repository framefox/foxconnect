import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import SvgIcon from "./SvgIcon";

function BulkMappingStatus({ statusUrl, bulkMappingsUrl, storeUrl, initialData }) {
  const [data, setData] = useState(initialData);
  const [isPolling, setIsPolling] = useState(
    initialData.status === "pending" || initialData.status === "processing"
  );
  const pollIntervalRef = useRef(null);

  useEffect(() => {
    if (isPolling) {
      // Poll every 2 seconds
      pollIntervalRef.current = setInterval(async () => {
        try {
          const response = await axios.get(statusUrl);
          setData({
            ...data,
            status: response.data.status,
            created_count: response.data.created_count,
            skipped_count: response.data.skipped_count,
            total_count: response.data.total_count,
            errors: response.data.errors || [],
          });

          // Stop polling if completed or failed
          if (response.data.status === "completed" || response.data.status === "failed") {
            setIsPolling(false);
          }
        } catch (error) {
          console.error("Error polling status:", error);
        }
      }, 2000);
    }

    return () => {
      if (pollIntervalRef.current) {
        clearInterval(pollIntervalRef.current);
      }
    };
  }, [isPolling, statusUrl]);

  const isProcessing = data.status === "pending" || data.status === "processing";
  const isCompleted = data.status === "completed";
  const isFailed = data.status === "failed";

  // Calculate progress
  const processedCount = (data.created_count || 0) + (data.skipped_count || 0);
  const progressPercent = data.total_count > 0 
    ? Math.round((processedCount / data.total_count) * 100) 
    : 0;

  return (
    <div className="space-y-6">
      {/* Status Card */}
      <div className="bg-white border border-slate-200 rounded-lg">
        <div className="p-6 border-b border-slate-200">
          <div className="flex items-center space-x-4">
            <div className="flex-shrink-0">
              {isProcessing && (
                <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                  <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-xl"></i>
                </div>
              )}
              {isCompleted && (
                <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                  <SvgIcon name="CheckIcon" className="w-6 h-6 text-green-600" />
                </div>
              )}
              {isFailed && (
                <div className="w-12 h-12 bg-red-100 rounded-full flex items-center justify-center">
                  <SvgIcon name="AlertTriangleIcon" className="w-6 h-6 text-red-600" />
                </div>
              )}
            </div>
            <div>
              <h2 className="text-lg font-semibold text-slate-900">
                {isProcessing && "Processing"}
                {isCompleted && "Completed"}
                {isFailed && "Failed"}
              </h2>
              <p className="text-sm text-slate-600">
                Variants with title "{data.variant_title}"
              </p>
            </div>
          </div>
        </div>

        <div className="p-6">
          {/* Processing Message with Progress Bar */}
          {isProcessing && (
            <div className="mb-6 space-y-4">
              {/* Progress Bar */}
              <div className="bg-slate-100 rounded-lg p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-slate-700">
                    Processing variants...
                  </span>
                  <span className="text-sm font-medium text-slate-900">
                    {processedCount} / {data.total_count} ({progressPercent}%)
                  </span>
                </div>
                <div className="w-full bg-slate-200 rounded-full h-3 overflow-hidden">
                  <div
                    className="bg-blue-600 h-3 rounded-full transition-all duration-500 ease-out"
                    style={{ width: `${progressPercent}%` }}
                  />
                </div>
                {processedCount > 0 && (
                  <div className="flex items-center gap-4 mt-2 text-xs text-slate-600">
                    <span>{data.created_count || 0} mapped</span>
                    {(data.skipped_count || 0) > 0 && (
                      <span>{data.skipped_count} skipped</span>
                    )}
                  </div>
                )}
              </div>

              {/* Info Message */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <SvgIcon name="InfoIcon" className="w-5 h-5 text-blue-600" />
                  </div>
                  <div className="ml-3">
                    <p className="text-sm text-blue-700">
                      You can continue using the app while this completes.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Completed Stats */}
          {isCompleted && (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
              <div className="bg-green-50 rounded-lg p-4">
                <div className="text-2xl font-bold text-green-700">
                  {data.created_count}
                </div>
                <div className="text-sm text-green-600">Variants mapped</div>
              </div>

              {data.skipped_count > 0 && (
                <div className="bg-slate-50 rounded-lg p-4">
                  <div className="text-2xl font-bold text-slate-700">
                    {data.skipped_count}
                  </div>
                  <div className="text-sm text-slate-600">
                    Already Mapped (Skipped)
                  </div>
                </div>
              )}

              <div className="bg-slate-50 rounded-lg p-4">
                <div className="text-2xl font-bold text-slate-700">
                  {data.total_count}
                </div>
                <div className="text-sm text-slate-600">Total Variants</div>
              </div>
            </div>
          )}

          {/* Failed Message */}
          {isFailed && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <div className="flex">
                <div className="flex-shrink-0">
                  <SvgIcon name="AlertTriangleIcon" className="w-5 h-5 text-red-600" />
                </div>
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-red-800">
                    Bulk mapping failed
                  </h3>
                  {data.errors && data.errors.length > 0 && (
                    <ul className="text-sm text-red-700 mt-1 list-disc list-inside">
                      {data.errors.map((error, index) => (
                        <li key={index}>{error}</li>
                      ))}
                    </ul>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Mapping Details */}
          <div className="border border-slate-200 rounded-lg p-4">
            <h3 className="text-sm font-medium text-slate-900 mb-3">
              Mapping Details
            </h3>
            <dl className="space-y-2">
              <div className="flex justify-between">
                <dt className="text-sm text-slate-600">Variant Title:</dt>
                <dd className="text-sm font-medium text-slate-900">
                  {data.variant_title}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-slate-600">Framefox Product:</dt>
                <dd className="text-sm font-medium text-slate-900">
                  {data.frame_sku_title}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-slate-600">
                  {isProcessing ? "Variants to Process:" : "Total Variants:"}
                </dt>
                <dd className="text-sm font-medium text-slate-900">
                  {data.total_count}
                </dd>
              </div>
            </dl>
          </div>

          {/* Errors (for completed with errors) */}
          {isCompleted && data.errors && data.errors.length > 0 && (
            <div className="mt-6 bg-amber-50 border border-amber-200 rounded-lg p-4">
              <h3 className="text-sm font-medium text-amber-800 mb-2">
                Some mappings had issues:
              </h3>
              <ul className="text-sm text-amber-700 space-y-1 list-disc list-inside">
                {data.errors.map((error, index) => (
                  <li key={index}>{error}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center space-x-4">
        <a
          href={bulkMappingsUrl}
          className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-slate-900 hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 transition-colors"
        >
          Bulk assign more products
        </a>
        <a
          href={storeUrl}
          className="inline-flex items-center px-4 py-2 border border-slate-300 text-sm font-medium rounded-md text-slate-700 bg-white hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 transition-colors"
        >
          Back to Store
        </a>
      </div>
    </div>
  );
}

export default BulkMappingStatus;
