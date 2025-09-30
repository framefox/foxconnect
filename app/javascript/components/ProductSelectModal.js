import React, { useState, useEffect, useCallback } from "react";
import Modal from "react-modal";
import axios from "axios";
import ProductSelectionStep from "./ProductSelectionStep";
import ArtworkSelectionStep from "./ArtworkSelectionStep";
import CropStep from "./CropStep";

// Make sure to bind modal to your appElement (https://reactcommunity.org/react-modal/accessibility/)
Modal.setAppElement("body");

const customStyles = {
  content: {
    top: "50%",
    left: "50%",
    right: "auto",
    bottom: "auto",
    marginRight: "-50%",
    transform: "translate(-50%, -50%)",
    width: "80%",
    height: "80vh",
    padding: "0",
    border: "none",
    borderRadius: "12px",
    boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)",
  },
  overlay: {
    backgroundColor: "rgba(0, 0, 0, 0.5)",
    zIndex: 1000,
  },
};

function ProductSelectModal({
  isOpen,
  onRequestClose,
  onProductSelect,
  productVariantId,
  orderItemId = null,
}) {
  const [step, setStep] = useState(1); // 1: Select Product, 2: Select Artwork, 3: Crop
  const [products, setProducts] = useState([]);
  const [artworks, setArtworks] = useState([]);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [selectedArtwork, setSelectedArtwork] = useState(null);
  const [loading, setLoading] = useState(false);
  const [artworkLoading, setArtworkLoading] = useState(false);
  const [error, setError] = useState(null);
  const [artworkError, setArtworkError] = useState(null);

  // Crop state
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState(null);
  const [cropSaving, setCropSaving] = useState(false);

  useEffect(() => {
    if (isOpen) {
      // Reset to step 1 when modal opens
      setStep(1);
      setSelectedProduct(null);
      setSelectedArtwork(null);
      setArtworks([]);
      setError(null);
      setArtworkError(null);
      setCrop({ x: 0, y: 0 });
      setZoom(1);
      setCroppedAreaPixels(null);
      fetchProducts();
    }
  }, [isOpen]);

  const fetchProducts = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(
        "https://shop.framefox.co.nz/api/shopify-customers/7315072254051/frame_skus.json?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
      );
      setProducts(response.data.frame_skus);
    } catch (err) {
      setError("Failed to load products. Please try again.");
      console.error("Error fetching products:", err);
    } finally {
      setLoading(false);
    }
  };

  const fetchArtworks = async () => {
    setArtworkLoading(true);
    setArtworkError(null);
    try {
      const response = await axios.get(
        "https://shop.framefox.co.nz/api/shopify-customers/7315072254051/images.json?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
      );
      setArtworks(response.data.images);
    } catch (err) {
      setArtworkError("Failed to load artworks. Please try again.");
      console.error("Error fetching artworks:", err);
    } finally {
      setArtworkLoading(false);
    }
  };

  const handleProductSelect = (product) => {
    setSelectedProduct(product);
    setStep(2);
    fetchArtworks();
  };

  const handleArtworkSelect = (artwork) => {
    setSelectedArtwork(artwork);
    setStep(3);
  };

  const handleUploadSuccess = (uploadData) => {
    console.log(
      "📤 Upload success in ProductSelectModal, refreshing artwork list"
    );

    // Refresh the artwork list to include the newly uploaded image
    fetchArtworks();
  };

  const handleBackToProducts = () => {
    setStep(1);
    setArtworkError(null);
  };

  const handleBackToArtworks = () => {
    setStep(2);
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setCroppedAreaPixels(null);
  };

  const getCropAspectRatio = () => {
    if (
      !selectedProduct?.long ||
      !selectedProduct?.short ||
      !selectedArtwork?.width ||
      !selectedArtwork?.height
    )
      return 1;

    const frameLong = parseFloat(selectedProduct.long);
    const frameShort = parseFloat(selectedProduct.short);
    const imageWidth = selectedArtwork.width;
    const imageHeight = selectedArtwork.height;

    // Determine if image is landscape (wider than tall) or portrait (taller than wide)
    const imageIsLandscape = imageWidth > imageHeight;

    // If image is landscape, use long/short ratio
    // If image is portrait, flip to short/long ratio
    return imageIsLandscape ? frameLong / frameShort : frameShort / frameLong;
  };

  const onCropComplete = useCallback((croppedArea, croppedAreaPixels) => {
    setCroppedAreaPixels(croppedAreaPixels);
  }, []);

  const handleSaveCrop = async () => {
    if (!croppedAreaPixels || !productVariantId) return;

    setCropSaving(true);
    try {
      const scaleFactor =
        Math.max(selectedArtwork.width, selectedArtwork.height) / 1000;

      const cropData = {
        variant_mapping: {
          product_variant_id: productVariantId,
          image_id: selectedArtwork.id,
          image_key: selectedArtwork.key,
          frame_sku_id: parseInt(selectedProduct.id, 10),
          frame_sku_code: selectedProduct.code,
          frame_sku_title: selectedProduct.description,
          frame_sku_cost_cents: selectedProduct.cost_cents,
          cx: Math.round(croppedAreaPixels.x * scaleFactor),
          cy: Math.round(croppedAreaPixels.y * scaleFactor),
          cw: Math.round(croppedAreaPixels.width * scaleFactor),
          ch: Math.round(croppedAreaPixels.height * scaleFactor),
          image_width: selectedArtwork.width,
          image_height: selectedArtwork.height,
          preview_url: selectedProduct.preview_image,
          cloudinary_id: selectedArtwork.cloudinary_id || selectedArtwork.key,
        },
      };

      // Add order_item_id if this is for a specific order item
      if (orderItemId) {
        cropData.order_item_id = orderItemId;
      }

      const response = await axios.post("/variant_mappings", cropData, {
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": document
            .querySelector('meta[name="csrf-token"]')
            .getAttribute("content"),
        },
      });

      // Check for successful HTTP status codes (200-299)
      if (response.status >= 200 && response.status < 300) {
        // Server returns variant mapping object directly on success
        onProductSelect({
          product: selectedProduct,
          artwork: selectedArtwork,
          crop: croppedAreaPixels,
          variantMapping: response.data, // Server returns variant mapping directly
        });
        onRequestClose();
      } else {
        console.error("Server error:", response.status, response.data);
      }
    } catch (error) {
      if (error.response?.data?.errors) {
        // Server returned validation errors
        console.error("Validation errors:", error.response.data.errors);
        alert("Error saving crop: " + error.response.data.errors.join(", "));
      } else {
        console.error("Network error:", error.response?.data || error.message);
        alert("Error saving crop. Please try again.");
      }
    } finally {
      setCropSaving(false);
    }
  };

  const getStepTitle = () => {
    switch (step) {
      case 1:
        return "Choose Product";
      case 2:
        return "Select an Artwork";
      case 3:
        return "Crop Image for Frame";
      default:
        return "Choose Product";
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      style={customStyles}
      contentLabel="Choose Product"
    >
      <div className="bg-white rounded-lg">
        {/* Modal Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <div className="flex items-center space-x-4">
            {step > 1 && (
              <button
                onClick={
                  step === 2 ? handleBackToProducts : handleBackToArtworks
                }
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <svg
                  className="w-6 h-6"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M15 19l-7-7 7-7"
                  />
                </svg>
              </button>
            )}
            <h2 className="text-xl font-semibold text-gray-900">
              {getStepTitle()}
            </h2>
          </div>
          <button
            onClick={onRequestClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <svg
              className="w-6 h-6"
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
        </div>

        {/* Modal Content */}
        <div
          className="p-6"
          style={{ maxHeight: "calc(80vh - 140px)", overflowY: "auto" }}
        >
          {/* Step 1: Product Selection */}
          {step === 1 && (
            <ProductSelectionStep
              loading={loading}
              error={error}
              products={products}
              onProductSelect={handleProductSelect}
              onRetry={fetchProducts}
            />
          )}

          {/* Step 2: Artwork Selection */}
          {step === 2 && (
            <ArtworkSelectionStep
              selectedProduct={selectedProduct}
              loading={artworkLoading}
              error={artworkError}
              artworks={artworks}
              onArtworkSelect={handleArtworkSelect}
              onRetry={fetchArtworks}
              onUploadSuccess={handleUploadSuccess}
            />
          )}

          {/* Step 3: Crop Image */}
          {step === 3 && selectedProduct && selectedArtwork && (
            <CropStep
              selectedProduct={selectedProduct}
              selectedArtwork={selectedArtwork}
              crop={crop}
              zoom={zoom}
              croppedAreaPixels={croppedAreaPixels}
              cropSaving={cropSaving}
              onCropChange={setCrop}
              onZoomChange={setZoom}
              onCropComplete={onCropComplete}
              onSaveCrop={handleSaveCrop}
              onBackToArtworks={handleBackToArtworks}
              getCropAspectRatio={getCropAspectRatio}
            />
          )}
        </div>
      </div>
    </Modal>
  );
}

export default ProductSelectModal;
