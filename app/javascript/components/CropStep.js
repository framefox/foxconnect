import React from "react";
import Cropper from "react-easy-crop";
import { SvgIcon } from "../components";

function CropStep({
  selectedProduct,
  selectedArtwork,
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
    if (!croppedAreaPixels) return 0;

    // Get actual crop dimensions in pixels from full-size image
    const scaleFactor =
      Math.max(selectedArtwork.width, selectedArtwork.height) / 1000;
    const cropWidthPx = croppedAreaPixels.width * scaleFactor;
    const cropHeightPx = croppedAreaPixels.height * scaleFactor;

    // Get print size in inches - map long/short to width/height based on orientation
    const long = parseFloat(selectedProduct.long) || 0;
    const short = parseFloat(selectedProduct.short) || 0;
    const unit = selectedProduct.unit || "in";

    // In landscape: width = long, height = short
    // In portrait: width = short, height = long
    const printWidth = isLandscape ? long : short;
    const printHeight = isLandscape ? short : long;

    let printWidthInches, printHeightInches;
    if (unit === "cm") {
      printWidthInches = printWidth / 2.54;
      printHeightInches = printHeight / 2.54;
    } else if (unit === "mm") {
      printWidthInches = printWidth / 25.4;
      printHeightInches = printHeight / 25.4;
    } else {
      // Assume inches
      printWidthInches = printWidth;
      printHeightInches = printHeight;
    }

    // Calculate DPI for width and height, return the minimum (limiting factor)
    const dpiWidth =
      printWidthInches > 0 ? Math.round(cropWidthPx / printWidthInches) : 0;
    const dpiHeight =
      printHeightInches > 0 ? Math.round(cropHeightPx / printHeightInches) : 0;

    return Math.min(dpiWidth, dpiHeight);
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
                  {selectedProduct.long || "N/A"} ×{" "}
                  {selectedProduct.short || "N/A"}
                  {selectedProduct.unit || '"'}
                </div>
              </div>

              {/* DPI */}
              <div>
                <span className="font-medium text-gray-300 block">DPI</span>
                <div className="text-white mt-1">
                  {croppedAreaPixels ? (
                    <>
                      {dpi}
                      {dpi < 125 && (
                        <span className="block text-xs text-amber-400 mt-1">
                          <SvgIcon
                            name="AlertTriangleIcon"
                            className="w-4 h-4 mr-1 inline"
                          />{" "}
                          Low resolution for print
                        </span>
                      )}
                      {dpi >= 125 && dpi < 200 && (
                        <span className="block text-xs text-blue-400 mt-1">
                          <SvgIcon
                            name="ThumbsUpIcon"
                            className="w-4 h-4 mr-1 inline"
                          />{" "}
                          Acceptable resolution
                        </span>
                      )}
                      {dpi >= 200 && (
                        <span className="block text-xs text-green-400 mt-1">
                          <SvgIcon
                            name="ThumbsUpIcon"
                            className="w-4 h-4 mr-1 inline"
                          />{" "}
                          High quality resolution
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
