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
    width: "90%",
    height: "90vh",
    padding: "0",
    border: "none",
    borderRadius: "12px",
    boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)",
    overflow: "hidden",
    display: "flex",
    flexDirection: "column",
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
  apiUrl,
  countryCode,
  replaceImageMode = false,
  existingVariantMapping = null,
}) {
  const [step, setStep] = useState(1); // 1: Select Product, 2: Select Artwork, 3: Crop
  const [products, setProducts] = useState([]);
  const [artworks, setArtworks] = useState([]);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [selectedArtwork, setSelectedArtwork] = useState(null);
  const [selectedProductType, setSelectedProductType] = useState(null);
  const [selectedCountryCode, setSelectedCountryCode] = useState(
    countryCode || "NZ"
  );
  const [loading, setLoading] = useState(false);
  const [artworkLoading, setArtworkLoading] = useState(false);
  const [error, setError] = useState(null);
  const [artworkError, setArtworkError] = useState(null);

  // Crop state
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState(null);
  const [cropSaving, setCropSaving] = useState(false);
  const [isLandscape, setIsLandscape] = useState(true); // Track orientation

  // Apply to variant state (only for order items)
  const [applyToVariant, setApplyToVariant] = useState(false);

  useEffect(() => {
    if (isOpen) {
      // Reset common state
      setSelectedArtwork(null);
      setArtworks([]);
      setError(null);
      setArtworkError(null);
      setCrop({ x: 0, y: 0 });
      setZoom(1);
      setCroppedAreaPixels(null);
      setApplyToVariant(false); // Reset checkbox state

      if (replaceImageMode && existingVariantMapping) {
        // Skip to artwork selection step and set up existing product data
        console.log("🔄 Replace image mode: Starting at artwork selection");
        setStep(2);
        setSelectedProduct({
          id: existingVariantMapping.frame_sku_id,
          code: existingVariantMapping.frame_sku_code,
          description: existingVariantMapping.frame_sku_title,
          cost_cents: existingVariantMapping.frame_sku_cost_cents,
          preview_image: existingVariantMapping.preview_url,
          long: existingVariantMapping.frame_sku_long,
          short: existingVariantMapping.frame_sku_short,
          unit: existingVariantMapping.frame_sku_unit,
        });
        fetchArtworks();
      } else {
        // Normal mode - start at step 1
        console.log("📦 Normal mode: Starting at product selection");
        setStep(1);
        setSelectedProduct(null);
        setSelectedProductType(null);
        fetchProducts();
      }
    }
  }, [isOpen, replaceImageMode, existingVariantMapping]);

  const fetchProducts = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(
        "http://dev.framefox.co.nz:3001/api/shopify-customers/7315072254051/frame_skus.json?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
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
        "http://dev.framefox.co.nz:3001/api/shopify-customers/7315072254051/images.json?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
      );
      setArtworks(response.data.images);
    } catch (err) {
      setArtworkError("Failed to load artworks. Please try again.");
      console.error("Error fetching artworks:", err);
    } finally {
      setArtworkLoading(false);
    }
  };

  const handleProductSelect = (product, customSize = null) => {
    // Normalize dimensions into the product object
    // long should always be the longer dimension, short the shorter
    const normalizedProduct = {
      ...product,
      long: customSize
        ? Math.max(customSize.user_width, customSize.user_height)
        : product.long,
      short: customSize
        ? Math.min(customSize.user_width, customSize.user_height)
        : product.short,
      unit: customSize ? customSize.user_unit : product.unit,
    };

    setSelectedProduct(normalizedProduct);
    setStep(2);
    fetchArtworks();
  };

  const handleArtworkSelect = (artwork) => {
    setSelectedArtwork(artwork);
    // Set initial orientation based on image dimensions
    setIsLandscape(artwork.width >= artwork.height);
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

    // Use the isLandscape state to determine orientation
    // If landscape, use long/short ratio
    // If portrait, flip to short/long ratio
    return isLandscape ? frameLong / frameShort : frameShort / frameLong;
  };

  const toggleOrientation = () => {
    setIsLandscape((prev) => !prev);
    // Reset crop position when orientation changes
    setCrop({ x: 0, y: 0 });
    setZoom(1);
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
          // Use existing frame SKU data if in replace image mode, otherwise use selected product
          frame_sku_id:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_id
              : parseInt(selectedProduct.id, 10),
          frame_sku_code:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_code
              : selectedProduct.code,
          frame_sku_title:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_title
              : selectedProduct.description,
          frame_sku_description:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_description
              : [
                  selectedProduct.title && `Size: ${selectedProduct.title}`,
                  selectedProduct.frame_style &&
                    `Frame: ${selectedProduct.frame_style}`,
                  selectedProduct.mat_style &&
                    `Mat: ${selectedProduct.mat_style}`,
                  selectedProduct.glass_type &&
                    `Glass: ${selectedProduct.glass_type}`,
                  selectedProduct.paper_type &&
                    `Paper: ${selectedProduct.paper_type}`,
                ]
                  .filter(Boolean)
                  .join(" | "),
          frame_sku_cost_cents:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_cost_cents
              : selectedProduct.cost_cents,
          frame_sku_long:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_long
              : selectedProduct.long,
          frame_sku_short:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_short
              : selectedProduct.short,
          frame_sku_unit:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.frame_sku_unit
              : selectedProduct.unit,
          cx: Math.round(croppedAreaPixels.x * scaleFactor),
          cy: Math.round(croppedAreaPixels.y * scaleFactor),
          cw: Math.round(croppedAreaPixels.width * scaleFactor),
          ch: Math.round(croppedAreaPixels.height * scaleFactor),
          image_width: selectedArtwork.width,
          image_height: selectedArtwork.height,
          preview_url:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.preview_url
              : selectedProduct.preview_image,
          cloudinary_id: selectedArtwork.cloudinary_id || selectedArtwork.key,
          image_filename: selectedArtwork.filename,
          country_code:
            replaceImageMode && existingVariantMapping
              ? existingVariantMapping.country_code
              : selectedProduct.country?.toUpperCase() || selectedCountryCode,
        },
      };

      // Add order_item_id if this is for a specific order item
      if (orderItemId) {
        cropData.order_item_id = orderItemId;
        // Add apply_to_variant flag if checkbox is checked
        cropData.apply_to_variant = applyToVariant;
      }

      // If in replace image mode, we need to update the existing variant mapping
      if (replaceImageMode && existingVariantMapping) {
        cropData.variant_mapping.id = existingVariantMapping.id;
      }

      // Use PUT for updates, POST for new mappings
      const isUpdate = replaceImageMode && existingVariantMapping;
      const url = isUpdate
        ? `/variant_mappings/${existingVariantMapping.id}`
        : "/variant_mappings";
      const method = isUpdate ? "put" : "post";

      const response = await axios[method](url, cropData, {
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
    if (replaceImageMode) {
      switch (step) {
        case 2:
          return "Select New Artwork";
        case 3:
          return "Crop New Image";
        default:
          return "Replace Image";
      }
    } else {
      switch (step) {
        case 1:
          // Show breadcrumb if product type is selected
          if (selectedProductType) {
            return (
              <span>
                <button
                  onClick={() => setSelectedProductType(null)}
                  className="text-slate-600 hover:text-slate-900 focus:outline-none focus:underline transition-colors"
                >
                  Choose Product
                </button>
                <span className="text-gray-400 mx-2">&gt;</span>
                <span>{selectedProductType}</span>
              </span>
            );
          }
          return "Choose Product";
        case 2:
          return "Select an Artwork";
        case 3:
          if (selectedProduct) {
            const unit = selectedProduct.unit || '"';
            return `Crop Image for ${selectedProduct.long || "N/A"} × ${
              selectedProduct.short || "N/A"
            }${unit}`;
          }
          return "Crop Image for Frame";
        default:
          return "Choose Product";
      }
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      style={customStyles}
      contentLabel="Choose Product"
    >
      <div
        className={`rounded-lg flex flex-col h-full ${
          step === 3 ? "bg-black" : "bg-white"
        }`}
      >
        {/* Modal Header */}
        <div
          className={`flex-shrink-0 flex items-center justify-between p-6 ${
            step === 3 ? "border-b border-zinc-800" : "border-b border-gray-200"
          }`}
        >
          <div className="flex items-center space-x-4">
            {step > 1 && (
              <button
                onClick={
                  step === 2 ? handleBackToProducts : handleBackToArtworks
                }
                className={`transition-colors ${
                  step === 3
                    ? "text-gray-400 hover:text-gray-200"
                    : "text-gray-400 hover:text-gray-600"
                }`}
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
            <h2
              className={`text-xl font-semibold ${
                step === 3 ? "text-white" : "text-gray-900"
              }`}
            >
              {getStepTitle()}
            </h2>
          </div>
          <button
            onClick={onRequestClose}
            className={`transition-colors ${
              step === 3
                ? "text-gray-400 hover:text-gray-200"
                : "text-gray-400 hover:text-gray-600"
            }`}
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

        {/* Order Item Context Hint */}
        {orderItemId && (
          <div className="">
            <div
              className=" border-slate-200 border-b p-6 leading-6"
              style={{
                backgroundImage:
                  "url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAYAAAAGCAYAAADgzO9IAAAADklEQVR4AWPAAXgHVBAAFvsATyVd4RkAAAAASUVORK5CYII=)",
                backgroundRepeat: "repeat",
              }}
            >
              <div className="flex items-center justify-center">
                <label className="flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={applyToVariant}
                    onChange={(e) => setApplyToVariant(e.target.checked)}
                    className="h-4 w-4 text-slate-900 border-slate-300 rounded focus:ring-slate-500"
                  />
                  <span className="ml-2 text-sm text-slate-700">
                    Apply this product and image to all future orders of this
                    product variant
                  </span>
                </label>
              </div>
            </div>
          </div>
        )}

        {/* Modal Content */}
        <div
          className={`flex-1 min-h-0 flex flex-col ${step === 3 ? "" : "p-6"}`}
        >
          {/* Step 1: Product Selection */}
          {step === 1 && !replaceImageMode && (
            <ProductSelectionStep
              loading={loading}
              error={error}
              products={products}
              apiUrl={apiUrl}
              countryCode={countryCode}
              onCountryChange={setSelectedCountryCode}
              onProductSelect={handleProductSelect}
              onRetry={fetchProducts}
              onProductTypeChange={setSelectedProductType}
              parentSelectedProductType={selectedProductType}
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
              countryCode={countryCode}
              isLandscape={isLandscape}
              onCropChange={setCrop}
              onZoomChange={setZoom}
              onCropComplete={onCropComplete}
              onSaveCrop={handleSaveCrop}
              onBackToArtworks={handleBackToArtworks}
              onToggleOrientation={toggleOrientation}
              getCropAspectRatio={getCropAspectRatio}
            />
          )}
        </div>
      </div>
    </Modal>
  );
}

export default ProductSelectModal;
