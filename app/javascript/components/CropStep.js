import React from "react";
import Cropper from "react-easy-crop";

function CropStep({
  selectedProduct,
  selectedArtwork,
  crop,
  zoom,
  croppedAreaPixels,
  cropSaving,
  onCropChange,
  onZoomChange,
  onCropComplete,
  onSaveCrop,
  onBackToArtworks,
  getCropAspectRatio,
}) {
  return (
    <>
      {/* Header */}
      <div className="mb-6 bg-slate-50 border border-slate-200 rounded-lg p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            {selectedProduct.preview_image && (
              <img
                src={selectedProduct.preview_image}
                alt={selectedProduct.description}
                className="h-12 w-12 object-contain rounded-md"
              />
            )}
            <div>
              <h4 className="text-sm font-medium text-gray-900">
                {selectedProduct.description}
              </h4>
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <img
              src={selectedArtwork.url}
              alt={selectedArtwork.filename}
              className="h-12 w-12 object-contain rounded-md"
            />
            <div>
              <h4 className="text-sm font-medium text-gray-900">
                {selectedArtwork.filename}
              </h4>
              <p className="text-xs text-gray-600">
                {selectedArtwork.width} × {selectedArtwork.height}px
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Two Column Crop Interface */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column - Crop Interface */}
        <div className="lg:col-span-2 space-y-4">
          <div
            className="relative bg-gray-900 rounded-lg overflow-hidden"
            style={{ height: "450px" }}
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

          {/* Zoom Control */}
          <div className="flex items-center space-x-4 bg-white p-4 rounded-lg border border-gray-200">
            <label className="text-sm font-medium text-gray-700">Zoom:</label>
            <input
              type="range"
              min={1}
              max={3}
              step={0.1}
              value={zoom}
              onChange={(e) => onZoomChange(parseFloat(e.target.value))}
              className="flex-1"
            />
            <span className="text-sm text-gray-600 w-12">
              {zoom.toFixed(1)}x
            </span>
          </div>
        </div>

        {/* Right Column - Info & Controls */}
        <div className="space-y-4">
          {/* Crop Info */}
          <div className="bg-gray-50 rounded-lg p-4">
            <h4 className="text-sm font-semibold text-gray-900 mb-3">
              Crop Details
            </h4>
            <div className="space-y-3 text-sm text-gray-600">
              <div>
                <span className="font-medium text-gray-700">Frame Ratio:</span>
                <div className="text-gray-900">
                  {getCropAspectRatio().toFixed(2)}
                </div>
              </div>
              <div>
                <span className="font-medium text-gray-700">Frame Size:</span>
                <div className="text-gray-900">
                  {selectedProduct.long || "N/A"} ×{" "}
                  {selectedProduct.short || "N/A"}
                </div>
              </div>
              <div>
                <span className="font-medium text-gray-700">Image Size:</span>
                <div className="text-gray-900">
                  {selectedArtwork.width} × {selectedArtwork.height}px
                </div>
              </div>
              {croppedAreaPixels && (
                <>
                  <div>
                    <span className="font-medium text-gray-700">
                      Preview Crop:
                    </span>
                    <div className="text-gray-900 font-mono text-xs">
                      {Math.round(croppedAreaPixels.x)},{" "}
                      {Math.round(croppedAreaPixels.y)} -{" "}
                      {Math.round(croppedAreaPixels.width)}×
                      {Math.round(croppedAreaPixels.height)}px
                    </div>
                  </div>
                  <div>
                    <span className="font-medium text-gray-700">
                      Full Size Crop:
                    </span>
                    <div className="text-gray-900 font-mono text-xs">
                      {Math.round(
                        croppedAreaPixels.x *
                          (Math.max(
                            selectedArtwork.width,
                            selectedArtwork.height
                          ) /
                            1000)
                      )}
                      ,{" "}
                      {Math.round(
                        croppedAreaPixels.y *
                          (Math.max(
                            selectedArtwork.width,
                            selectedArtwork.height
                          ) /
                            1000)
                      )}{" "}
                      -{" "}
                      {Math.round(
                        croppedAreaPixels.width *
                          (Math.max(
                            selectedArtwork.width,
                            selectedArtwork.height
                          ) /
                            1000)
                      )}
                      ×
                      {Math.round(
                        croppedAreaPixels.height *
                          (Math.max(
                            selectedArtwork.width,
                            selectedArtwork.height
                          ) /
                            1000)
                      )}
                      px
                    </div>
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Action Buttons */}
          <div className="space-y-3">
            <button
              onClick={onSaveCrop}
              disabled={!croppedAreaPixels || cropSaving}
              className="w-full px-4 py-3 border border-transparent rounded-md shadow-sm text-sm font-medium text-slate-50 bg-slate-900 hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {cropSaving ? (
                <>
                  <i className="fa-solid fa-spinner-third fa-spin text-white mr-2"></i>
                  Saving...
                </>
              ) : (
                "Save Crop"
              )}
            </button>
            <button
              onClick={onBackToArtworks}
              className="w-full px-4 py-2 bg-slate-100 text-slate-900 hover:bg-slate-200 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
            >
              Back to Artworks
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

export default CropStep;
