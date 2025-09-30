import React, { useState } from "react";
import ProductSelectModal from "./ProductSelectModal";
import axios from "axios";

function OrderItemCard({ item, currency }) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [variantMapping, setVariantMapping] = useState(
    item.variant_mapping || null
  );
  const [imageLoading, setImageLoading] = useState(true);
  const [isRemoving, setIsRemoving] = useState(false);

  const hasVariantMapping = variantMapping !== null;

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency || "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  };

  const handleRemoveMapping = async () => {
    if (!confirm("Are you sure you want to remove this product and image?")) {
      return;
    }

    setIsRemoving(true);
    try {
      const response = await axios.delete(
        `/orders/${item.order_id}/order_items/${item.id}/remove_variant_mapping`,
        {
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        }
      );

      if (response.status >= 200 && response.status < 300) {
        setVariantMapping(null);
        console.log("Variant mapping removed successfully");
      }
    } catch (error) {
      console.error("Error removing variant mapping:", error);
      alert("Failed to remove variant mapping. Please try again.");
    } finally {
      setIsRemoving(false);
    }
  };

  return (
    <div className="p-6">
      <div className="flex items-start space-x-4">
        {/* Product Image */}
        <div className="w-24 h-24 bg-slate-100 rounded-lg flex items-center justify-center flex-shrink-0">
          {hasVariantMapping && variantMapping.framed_preview_thumbnail ? (
            <div className="h-24 w-24 relative flex items-center justify-center">
              {imageLoading && (
                <div className="absolute inset-0 flex items-center justify-center bg-slate-100 rounded-lg">
                  <i className="fa-solid fa-spinner-third fa-spin text-slate-400"></i>
                </div>
              )}
              <img
                src={variantMapping.framed_preview_thumbnail}
                alt={item.display_name}
                className={`${
                  variantMapping.ch > variantMapping.cw ? "h-full" : "w-full"
                } object-contain ${
                  imageLoading ? "opacity-0" : "opacity-100"
                } transition-opacity duration-200`}
                onLoad={() => setImageLoading(false)}
                onError={() => setImageLoading(false)}
              />
            </div>
          ) : (
            <i className="fa-solid fa-image text-slate-400"></i>
          )}
        </div>

        {/* Product Details */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <h4 className="font-medium text-slate-900 mt-4">
                {item.display_name}
              </h4>
              {item.sku && (
                <p className="text-sm text-slate-500 mt-1">SKU: {item.sku}</p>
              )}
              <div className="flex items-center space-x-4 mt-2">
                <span className="text-sm text-slate-600">
                  Qty: {item.quantity}
                </span>
              </div>
              {hasVariantMapping && (
                <div className="flex items-center justify-between mt-2 p-3 bg-slate-100 rounded-sm">
                  <div className="text-sm font-medium text-slate-900">
                    Fulfilled as{" "}
                    <span className="font-bold">
                      {variantMapping.frame_sku_title} print /{" "}
                      {variantMapping.frame_sku_code}
                    </span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                      <i className="fa-solid fa-check w-3 h-3 mr-1"></i>
                      Ready
                    </span>
                    <button
                      onClick={handleRemoveMapping}
                      disabled={isRemoving}
                      className="inline-flex items-center px-2 py-1 text-xs leading-4 font-medium rounded text-slate-700 bg-white hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      title="Remove variant mapping"
                    >
                      {isRemoving ? (
                        <i className="fa-solid fa-spinner-third fa-spin w-3 h-3"></i>
                      ) : (
                        <i className="fa-solid fa-times w-3 h-3"></i>
                      )}
                    </button>
                  </div>
                </div>
              )}
            </div>
            <div className="text-right">
              {!hasVariantMapping && (
                <button
                  onClick={() => setIsModalOpen(true)}
                  className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-yellow-800 bg-yellow-100 hover:bg-yellow-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950 transition-colors"
                >
                  <i className="fa-solid fa-search w-3 h-3 mr-2 "></i>
                  Choose product & image
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Product Select Modal */}
      {item.product_variant_id && (
        <ProductSelectModal
          isOpen={isModalOpen}
          onRequestClose={() => setIsModalOpen(false)}
          productVariantId={item.product_variant_id}
          orderItemId={item.id}
          onProductSelect={(selection) => {
            if (selection.variantMapping) {
              setVariantMapping(selection.variantMapping);
              setImageLoading(true);
              console.log("Variant mapping created:", selection.variantMapping);

              // Refresh the page to reflect the updated order item variant mapping
              // This ensures the backend state is properly reflected in the UI
              setTimeout(() => {
                window.location.reload();
              }, 1000);
            }
          }}
        />
      )}
    </div>
  );
}

export default OrderItemCard;
