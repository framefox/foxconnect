import React, { useState } from "react";

function CustomPrintSizeModal({ isOpen, onClose, onSubmit, apiUrl }) {
  const [width, setWidth] = useState("");
  const [height, setHeight] = useState("");
  const [unit, setUnit] = useState("mm");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);
  const [matchedSize, setMatchedSize] = useState(null);

  // Get the API auth token
  const getApiAuthToken = () => {
    return window.FramefoxConfig?.apiAuthToken || null;
  };

  // Helper function to add auth parameter to URL
  const addAuthToUrl = (url) => {
    const authToken = getApiAuthToken();
    if (!authToken) {
      console.warn("API auth token not available");
      return url;
    }
    const separator = url.includes("?") ? "&" : "?";
    return `${url}${separator}auth=${authToken}`;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    // Validate inputs
    if (!width || !height) {
      setError("Please enter both width and height");
      return;
    }

    if (parseFloat(width) <= 0 || parseFloat(height) <= 0) {
      setError("Width and height must be positive numbers");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams({
        width: width,
        height: height,
        unit: unit,
      });

      const url = addAuthToUrl(`${apiUrl}/frame_sku_sizes/match?${params.toString()}`);
      const response = await fetch(url);

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        throw new Error(
          errorData?.error || `Failed to match size: ${response.statusText}`
        );
      }

      const data = await response.json();

      if (!data.frame_sku_size || !data.frame_sku_size.id) {
        throw new Error("No matching frame size found for these dimensions");
      }

      // Calculate long/short dimensions (long is always the longer dimension)
      const numWidth = parseFloat(width);
      const numHeight = parseFloat(height);
      const long = Math.max(numWidth, numHeight);
      const short = Math.min(numWidth, numHeight);

      // Save to database
      const saveResponse = await fetch("/custom_print_sizes", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": document
            .querySelector('meta[name="csrf-token"]')
            .getAttribute("content"),
        },
        body: JSON.stringify({
          custom_print_size: {
            long: long,
            short: short,
            unit: unit,
            frame_sku_size_id: data.frame_sku_size.id,
            frame_sku_size_description: data.frame_sku_size.size_description,
          },
        }),
      });

      if (!saveResponse.ok) {
        const errorData = await saveResponse.json().catch(() => null);
        throw new Error(
          errorData?.errors?.join(", ") || "Failed to save custom size"
        );
      }

      const savedCustomSize = await saveResponse.json();

      // Store the matched size and show success state
      setMatchedSize({
        id: savedCustomSize.id,
        frame_sku_size_id: savedCustomSize.frame_sku_size_id,
        frame_sku_size_title: savedCustomSize.frame_sku_size_description,
        user_width: width,
        user_height: height,
        user_unit: unit,
        long: savedCustomSize.long,
        short: savedCustomSize.short,
        dimensions_display: savedCustomSize.dimensions_display,
        full_description: savedCustomSize.full_description,
      });
      setSuccess(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    if (!loading) {
      setError(null);
      setSuccess(false);
      setMatchedSize(null);
      setWidth("");
      setHeight("");
      setUnit("mm");
      onClose();
    }
  };

  const handleConfirm = () => {
    if (matchedSize) {
      onSubmit(matchedSize);
      handleClose();
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black opacity-50 transition-opacity"
        onClick={handleClose}
      ></div>

      {/* Modal */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="relative bg-white rounded-xl shadow-2xl max-w-xl w-full"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Close button */}
          <button
            type="button"
            onClick={handleClose}
            disabled={loading}
            className="absolute top-4 right-4 text-slate-400 hover:text-slate-600 transition-colors"
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

          {/* Success State */}
          {success ? (
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
                      strokeWidth="2"
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                </div>
              </div>

              {/* Success Message */}
              <h2 className="text-xl font-semibold text-slate-900 text-center mb-2">
                Custom Print Size Created
              </h2>
              <p className="text-sm text-slate-600 text-center mb-6">
                Note: This size will use the price of{" "}
                {matchedSize?.frame_sku_size_title} which is the nearest
                standard size.
              </p>

              {/* Matched Size Details */}
              <div className="bg-slate-50 border border-slate-200 rounded-lg p-4 mb-6">
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium text-slate-700">
                      Your Dimensions:
                    </span>
                    <span className="text-sm text-slate-900 font-semibold">
                      {matchedSize?.user_width} × {matchedSize?.user_height}{" "}
                      {matchedSize?.user_unit}
                    </span>
                  </div>
                  <div className="border-t border-slate-200"></div>
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium text-slate-700">
                      Priced as:
                    </span>
                    <span className="text-sm text-slate-900 font-semibold">
                      {matchedSize?.frame_sku_size_title}
                    </span>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => {
                    setSuccess(false);
                    setMatchedSize(null);
                  }}
                  className="flex-1 px-4 py-2.5 bg-slate-100 text-slate-700 text-sm font-medium rounded-md hover:bg-slate-200 transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
                >
                  Try Different Size
                </button>
                <button
                  type="button"
                  onClick={handleConfirm}
                  className="flex-1 px-4 py-2.5 bg-slate-900 text-white text-sm font-medium rounded-md hover:bg-slate-800 transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
                >
                  Confirm & Continue
                </button>
              </div>
            </div>
          ) : (
            <>
              {/* Header */}
              <div className="px-6 pt-6 pb-4">
                <h2 className="text-xl font-semibold text-slate-900">
                  Define a custom print size
                </h2>
                <p className="mt-2 text-sm text-slate-600">
                  Enter your custom dimensions in mm/cm/inches, or contact us if
                  you need assistance.
                </p>
                <p className="mt-2 text-xs text-red-600 font-medium">
                  Note: Maximum combined width and height is 2,030mm
                </p>
              </div>

              {/* Form */}
              <form onSubmit={handleSubmit} className="px-6 pb-6">
                <div className="space-y-4">
                  {/* Inputs Section - All Inline */}
                  <div className="flex items-end gap-3">
                    {/* Width Input */}
                    <div className="flex-1">
                      <label className="block text-xs font-medium text-slate-700 mb-1">
                        Width
                      </label>
                      <input
                        type="number"
                        step="0.01"
                        value={width}
                        onChange={(e) => setWidth(e.target.value)}
                        placeholder="0.00"
                        className="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-slate-950 focus:border-slate-950 placeholder-slate-400"
                        disabled={loading}
                      />
                    </div>

                    {/* Height Input */}
                    <div className="flex-1">
                      <label className="block text-xs font-medium text-slate-700 mb-1">
                        Height
                      </label>
                      <input
                        type="number"
                        step="0.01"
                        value={height}
                        onChange={(e) => setHeight(e.target.value)}
                        placeholder="0.00"
                        className="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-slate-950 focus:border-slate-950 placeholder-slate-400"
                        disabled={loading}
                      />
                    </div>

                    {/* Unit Selection */}
                    <div className="flex-shrink-0">
                      <label className="block text-xs font-medium text-slate-700 mb-1">
                        Unit
                      </label>
                      <div className="flex gap-1 border border-slate-300 rounded-md p-0.5 bg-white">
                        {["cm", "mm", "in"].map((unitOption) => (
                          <button
                            key={unitOption}
                            type="button"
                            onClick={() => setUnit(unitOption)}
                            disabled={loading}
                            className={`px-2.5 py-1.5 text-xs font-medium rounded transition-colors focus:outline-none focus:ring-1 focus:ring-slate-950 ${
                              unit === unitOption
                                ? "bg-slate-900 text-white shadow-sm"
                                : "text-slate-600 hover:bg-slate-50"
                            }`}
                          >
                            {unitOption}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>

                  {/* Error Message */}
                  {error && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                      <p className="text-xs text-red-700">{error}</p>
                    </div>
                  )}

                  {/* Submit Button */}
                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full mt-3 px-4 py-2.5 bg-slate-900 text-white text-sm font-medium rounded-md hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
                  >
                    {loading ? (
                      <>
                        <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                        Searching...
                      </>
                    ) : (
                      "Save Custom Size"
                    )}
                  </button>
                </div>
              </form>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default CustomPrintSizeModal;
