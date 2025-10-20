import React from "react";
import Cropper from "react-easy-crop";

function CropStep({
  selectedProduct,
  selectedArtwork,
  customSizeData,
  crop,
  zoom,
  croppedAreaPixels,
  cropSaving,
  isLandscape,
  onCropChange,
  onZoomChange,
  onCropComplete,
  onSaveCrop,
  onBackToArtworks,
  onToggleOrientation,
  getCropAspectRatio,
}) {
  // Calculate DPI based on crop dimensions and print size
  const calculateDPI = () => {
    if (!croppedAreaPixels) return { width: 0, height: 0 };

    // Get actual crop dimensions in pixels from full-size image
    const scaleFactor =
      Math.max(selectedArtwork.width, selectedArtwork.height) / 1000;
    const cropWidthPx = croppedAreaPixels.width * scaleFactor;
    const cropHeightPx = croppedAreaPixels.height * scaleFactor;

    // Get print size in inches
    let printWidthInches, printHeightInches;

    if (customSizeData) {
      // Convert custom size to inches if needed
      if (customSizeData.user_unit === "cm") {
        printWidthInches = customSizeData.user_width / 2.54;
        printHeightInches = customSizeData.user_height / 2.54;
      } else if (customSizeData.user_unit === "mm") {
        printWidthInches = customSizeData.user_width / 25.4;
        printHeightInches = customSizeData.user_height / 25.4;
      } else {
        // Assume inches
        printWidthInches = customSizeData.user_width;
        printHeightInches = customSizeData.user_height;
      }
    } else {
      // Use product dimensions (assuming they're in inches)
      printWidthInches = parseFloat(selectedProduct.long) || 0;
      printHeightInches = parseFloat(selectedProduct.short) || 0;
    }

    // Calculate DPI for width and height
    const dpiWidth =
      printWidthInches > 0 ? Math.round(cropWidthPx / printWidthInches) : 0;
    const dpiHeight =
      printHeightInches > 0 ? Math.round(cropHeightPx / printHeightInches) : 0;

    return { width: dpiWidth, height: dpiHeight };
  };

  const dpi = calculateDPI();

  return (
    <div className="h-full  flex flex-col">
      {/* Custom styling for react-easy-crop */}
      <style>
        {`
          .reactEasyCrop_CropArea {
            color: rgb(0 0 0 / 65%) !important;
          }
        `}
      </style>

      {/* Two Column Crop Interface */}
      <div className="grid grid-cols-1 lg:grid-cols-3  flex-1">
        {/* Left Column - Crop Interface */}
        <div className="lg:col-span-2 flex items-center">
          <div
            className="relative overflow-hidden flex items-center justify-center w-full"
            style={{ height: "100%", backgroundColor: "#222" }}
          >
            <Cropper
              image={selectedArtwork.url}
              crop={crop}
              zoom={zoom}
              aspect={getCropAspectRatio()}
              onCropChange={onCropChange}
              onZoomChange={onZoomChange}
              onCropComplete={onCropComplete}
            />
          </div>
        </div>

        {/* Right Column - Info & Controls */}
        <div className="space-y-4 px-6 py-6">
          {/* Crop Details */}
          <div className="p-4 ">
            <h4 className="text-sm font-semibold text-white mb-3">
              Crop Details
            </h4>
            <div className="space-y-3 text-sm">
              {/* Zoom Control */}
              <div>
                <label className="font-medium text-gray-300 block mb-2">
                  Zoom
                </label>
                <div className="flex items-center space-x-3">
                  <input
                    type="range"
                    min={1}
                    max={3}
                    step={0.1}
                    value={zoom}
                    onChange={(e) => onZoomChange(parseFloat(e.target.value))}
                    className="flex-1"
                  />
                  <span className="text-sm text-gray-400 w-12">
                    {zoom.toFixed(1)}x
                  </span>
                </div>
              </div>

              {/* Toggle Orientation */}
              <div>
                <label className="font-medium text-gray-300 block mb-2">
                  Orientation
                </label>
                <button
                  onClick={onToggleOrientation}
                  className="w-full flex items-center justify-between px-3 py-2 bg-zinc-800 hover:bg-zinc-700 rounded-md transition-colors border border-zinc-700"
                >
                  <span className="text-sm text-white">
                    {isLandscape ? "Landscape" : "Portrait"}
                  </span>
                  <svg
                    className="w-5 h-5 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                    />
                  </svg>
                </button>
              </div>

              {/* Image Size */}
              <div>
                <span className="font-medium text-gray-300 block">
                  Image Size
                </span>
                <div className="text-white mt-1">
                  {selectedArtwork.width} × {selectedArtwork.height}px
                </div>
              </div>

              {/* Print Size */}
              <div>
                <span className="font-medium text-gray-300 block">
                  Print Size
                </span>
                <div className="text-white mt-1">
                  {customSizeData ? (
                    <>
                      <span className="font-semibold">
                        {customSizeData.user_width} ×{" "}
                        {customSizeData.user_height}
                        {customSizeData.user_unit}
                      </span>
                    </>
                  ) : (
                    <>
                      {selectedProduct.long || "N/A"} ×{" "}
                      {selectedProduct.short || "N/A"}
                      {selectedProduct.unit || '"'}
                    </>
                  )}
                </div>
              </div>

              {/* DPI */}
              <div>
                <span className="font-medium text-gray-300 block">DPI</span>
                <div className="text-white mt-1">
                  {croppedAreaPixels ? (
                    <>
                      {dpi.width} × {dpi.height}
                      {(dpi.width < 150 || dpi.height < 150) && (
                        <span className="block text-xs text-amber-400 mt-1">
                          ⚠ Low resolution for print
                        </span>
                      )}
                      {dpi.width >= 150 &&
                        dpi.height >= 150 &&
                        dpi.width < 300 &&
                        dpi.height < 300 && (
                          <span className="block text-xs text-blue-400 mt-1">
                            ✓ Acceptable resolution
                          </span>
                        )}
                      {dpi.width >= 300 && dpi.height >= 300 && (
                        <span className="block text-xs text-green-400 mt-1">
                          ✓ High quality resolution
                        </span>
                      )}
                    </>
                  ) : (
                    "—"
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="space-y-3">
            <button
              onClick={onSaveCrop}
              disabled={!croppedAreaPixels || cropSaving}
              className="w-full px-4 py-3 border border-transparent rounded-md text-sm font-medium text-black bg-white hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-white disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {cropSaving ? (
                <>
                  <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                  Saving...
                </>
              ) : (
                "Save Crop"
              )}
            </button>
            <button
              onClick={onBackToArtworks}
              className="w-full px-4 py-2 bg-zinc-800 text-white hover:bg-zinc-700 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-zinc-600 focus:ring-offset-2 focus:ring-offset-black border border-zinc-700"
            >
              Back to Artworks
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default CropStep;
