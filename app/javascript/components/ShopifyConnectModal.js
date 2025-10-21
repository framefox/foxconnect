import React from "react";
import { SvgIcon } from "../components";

function ShopifyConnectModal({ isOpen, onClose, connectUrl }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto text-left">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black opacity-50 transition-opacity"
        onClick={onClose}
      ></div>

      {/* Modal */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="relative bg-white rounded-xl shadow-2xl max-w-lg w-full"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Close button */}
          <button
            type="button"
            onClick={onClose}
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
            <div className="flex items-center space-x-3 mb-3">
              <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                <svg
                  className="w-6 h-6 text-green-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
              </div>
              <h2 className="text-xl font-semibold text-slate-900">
                Connect to Shopify
              </h2>
            </div>
            <p className="text-sm text-slate-600">
              Framefox Connect will request access to the following data from
              your Shopify store:
            </p>
          </div>

          {/* Permissions List */}
          <div className="px-6 pb-4 mt-3">
            <div className="space-y-5">
              {/* Products */}
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center mt-0.5">
                  <SvgIcon
                    name="ProductFilledIcon"
                    className="w-5 h-5 text-blue-600"
                  />
                </div>
                <div className="flex-1">
                  <h3 className="text-sm font-medium text-slate-900">
                    Products
                  </h3>
                  <p className="text-sm text-slate-600 mt-0.5">
                    Sync your product catalog to enable drop-shipping of your
                    products.
                  </p>
                </div>
              </div>

              {/* Orders */}
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0 w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center mt-0.5">
                  <SvgIcon
                    name="OrderFilledIcon"
                    className="w-5 h-5 text-purple-600"
                  />
                </div>
                <div className="flex-1">
                  <h3 className="text-sm font-medium text-slate-900">Orders</h3>
                  <p className="text-sm text-slate-600 mt-0.5">
                    Automatically import orders that need fulfillment from
                    Framefox.
                  </p>
                </div>
              </div>

              {/* Fulfillments */}
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0 w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center mt-0.5">
                  <SvgIcon
                    name="DeliveryFilledIcon"
                    className="w-5 h-5 text-green-600"
                  />
                </div>
                <div className="flex-1">
                  <h3 className="text-sm font-medium text-slate-900">
                    Fulfillments
                  </h3>
                  <p className="text-sm text-slate-600 mt-0.5">
                    This allows tracking in your orders to automatically update
                    when items ship from Framefox.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Privacy Notice */}
          <div className="px-6 pb-4">
            <div className="bg-slate-50 border border-slate-200 rounded-lg p-3">
              <p className="text-xs text-slate-600">
                <span className="font-medium text-slate-700">Privacy:</span> We
                only access the data necessary to fulfill your orders. Your
                store data is secure and never shared with third parties.
              </p>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="px-6 pb-6">
            <div className="flex gap-3">
              <button
                type="button"
                onClick={onClose}
                className="flex-1 px-4 py-2.5 bg-slate-100 text-slate-700 text-sm font-medium rounded-md hover:bg-slate-200 transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
              >
                Cancel
              </button>
              <a
                href={connectUrl}
                className="flex-1 px-4 py-2.5 bg-slate-900 text-white text-sm font-medium rounded-md hover:bg-slate-800 transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 text-center"
              >
                Connect Shopify
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default ShopifyConnectModal;
