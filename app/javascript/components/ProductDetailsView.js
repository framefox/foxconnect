import React from "react";
import VariantCard from "./VariantCard";

function ProductDetailsView({ product, store, variants }) {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
      {/* Product Image & Metadata (1/3) */}
      <div className="space-y-4">
        <div className="aspect-square bg-slate-50 rounded-lg border border-slate-200 flex items-center justify-center">
          {product.featured_image_url ? (
            <img
              src={product.featured_image_url}
              alt={product.title}
              className="w-full h-full object-cover rounded-lg"
            />
          ) : (
            <div className="text-center space-y-2">
              <svg
                className="w-16 h-16 text-slate-400 mx-auto"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
              <p className="text-sm text-slate-500">No image available</p>
            </div>
          )}
        </div>

        {/* Product Metadata */}
        <div>
          <h3 className="text-lg font-semibold text-slate-900 mb-4">Details</h3>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-slate-600">Created:</span>
              <span className="text-slate-900">
                {new Date(product.created_at).toLocaleDateString("en-US", {
                  year: "numeric",
                  month: "long",
                  day: "numeric",
                })}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-600">Updated:</span>
              <span className="text-slate-900">
                {new Date(product.updated_at).toLocaleDateString("en-US", {
                  year: "numeric",
                  month: "long",
                  day: "numeric",
                })}
              </span>
            </div>
            {product.published_at && (
              <div className="flex justify-between">
                <span className="text-slate-600">Published:</span>
                <span className="text-slate-900">
                  {new Date(product.published_at).toLocaleDateString("en-US", {
                    year: "numeric",
                    month: "long",
                    day: "numeric",
                  })}
                </span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Variants Section (2/3) */}
      <div className="lg:col-span-2">
        <div className="space-y-4">
          {variants.map((variant) => (
            <VariantCard
              key={variant.id}
              variant={{
                id: variant.id,
                title: variant.title,
                external_variant_id: variant.external_variant_id,
                fulfilment_active: variant.fulfilment_active,
              }}
              storeId={store.id}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

export default ProductDetailsView;
