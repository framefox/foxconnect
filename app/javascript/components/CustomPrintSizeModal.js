import React, { useState } from "react";

function CustomPrintSizeModal({ isOpen, onClose, onSubmit, apiUrl }) {
  const [width, setWidth] = useState("");
  const [height, setHeight] = useState("");
  const [unit, setUnit] = useState("cm");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

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

      const response = await fetch(
        `${apiUrl}/frame_sku_sizes/match?${params.toString()}`
      );

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

      // Call parent with the data
      onSubmit({
        frame_sku_size_id: data.frame_sku_size.id,
        frame_sku_size_title: data.frame_sku_size.size_description,
        user_width: width,
        user_height: height,
        user_unit: unit,
      });

      // Reset form
      setWidth("");
      setHeight("");
      setUnit("cm");
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    if (!loading) {
      setError(null);
      onClose();
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

          {/* Header */}
          <div className="px-6 pt-6 pb-4">
            <h2 className="text-xl font-semibold text-slate-900">
              Define a custom print size
            </h2>
            <p className="mt-2 text-sm text-slate-600">
              Enter your custom dimensions in mm/cm/inches, or contact us if you
              need assistance.
            </p>
            <p className="mt-2 text-xs text-red-600 font-medium">
              Note: Maximum print area is A0 (1189×841mm)
            </p>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="px-6 pb-6">
            <div className="space-y-4">
              {/* Inputs Section */}
              <div className="flex items-center justify-center gap-3">
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
              </div>

              {/* Unit Selection */}
              <div>
                <label className="block text-xs font-medium text-slate-700 mb-2">
                  Unit
                </label>
                <div className="flex gap-2">
                  {["cm", "mm", "in"].map((unitOption) => (
                    <button
                      key={unitOption}
                      type="button"
                      onClick={() => setUnit(unitOption)}
                      disabled={loading}
                      className={`flex-1 px-4 py-2 text-sm font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 ${
                        unit === unitOption
                          ? "bg-slate-900 text-white"
                          : "bg-slate-100 text-slate-700 hover:bg-slate-200"
                      }`}
                    >
                      {unitOption}
                    </button>
                  ))}
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
                className="w-full px-4 py-2.5 bg-slate-900 text-white text-sm font-medium rounded-md hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
              >
                {loading ? (
                  <>
                    <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                    Searching...
                  </>
                ) : (
                  "Set Custom Size"
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}

export default CustomPrintSizeModal;
