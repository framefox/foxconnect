import React, { useState } from "react";
import axios from "axios";
import { SvgIcon } from "../components";

function SubmitProductionButton({ orderId, canSubmit }) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [steps, setSteps] = useState({
    step1: { name: "Sending order to Framefox production", status: "pending" },
    step2: {
      name: "Retreiving final product and shipping costs",
      status: "pending",
    },
    step3: { name: "Completing...", status: "pending" },
  });
  const [error, setError] = useState(null);
  const [failedStep, setFailedStep] = useState(null);

  const getStepIcon = (status) => {
    switch (status) {
      case "success":
        return (
          <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
            <i className="fa-solid fa-check text-green-600 text-xs"></i>
          </div>
        );
      case "loading":
        return (
          <div className="w-6 h-6 flex items-center justify-center">
            <i className="fa-solid fa-spinner fa-spin text-blue-600"></i>
          </div>
        );
      case "error":
        return (
          <div className="w-6 h-6 bg-red-100 rounded-full flex items-center justify-center">
            <i className="fa-solid fa-times text-red-600 text-xs"></i>
          </div>
        );
      default:
        return (
          <div className="w-6 h-6 bg-slate-100 rounded-full flex items-center justify-center">
            <div className="w-2 h-2 bg-slate-400 rounded-full"></div>
          </div>
        );
    }
  };

  const handleSubmit = async () => {
    setIsSubmitting(true);
    setError(null);
    setFailedStep(null);

    // Set all steps to loading initially
    setSteps({
      step1: { ...steps.step1, status: "loading" },
      step2: { ...steps.step2, status: "pending" },
      step3: { ...steps.step3, status: "pending" },
    });

    try {
      const csrfToken = document.querySelector("[name='csrf-token']").content;
      const response = await axios.post(
        `/orders/${orderId}/submit_production`,
        {},
        {
          headers: {
            "X-CSRF-Token": csrfToken,
            "Content-Type": "application/json",
          },
        }
      );

      if (response.data.success) {
        setSteps(response.data.steps);
        // Wait a moment to show success, then redirect
        setTimeout(() => {
          window.location.href = response.data.redirect_url;
        }, 1000);
      }
    } catch (err) {
      const errorData = err.response?.data || {};
      setError(errorData.error || "An unexpected error occurred");
      setFailedStep(errorData.failed_step);
      if (errorData.steps) {
        setSteps(errorData.steps);
      }
      setIsSubmitting(false);
    }
  };

  const openModal = () => {
    setIsModalOpen(true);
    // Reset state when opening modal
    setSteps({
      step1: {
        name: "Sending order to Framefox production",
        status: "pending",
      },
      step2: {
        name: "Retreiving final product and shipping costs",
        status: "pending",
      },
      step3: { name: "Completing...", status: "pending" },
    });
    setError(null);
    setFailedStep(null);
  };

  const closeModal = () => {
    if (!isSubmitting) {
      setIsModalOpen(false);
    }
  };

  return (
    <>
      {canSubmit ? (
        <button
          onClick={openModal}
          className="block text-center w-full bg-slate-900 hover:bg-slate-700 text-white font-medium py-3 px-4 rounded-lg transition-colors"
        >
          Submit for Production
          <i className="fa-solid fa-arrow-right ml-2 h-4 w-4"></i>
        </button>
      ) : (
        <button
          disabled
          className="block text-center w-full bg-slate-300 text-slate-500 font-medium py-3 px-4 rounded-lg cursor-not-allowed opacity-60"
        >
          Submit for Production
          <i className="fa-solid fa-arrow-right ml-2 h-4 w-4"></i>
        </button>
      )}

      {/* Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4">
            {/* Background overlay */}
            <div
              className="fixed inset-0 bg-slate-500 opacity-75 transition-opacity"
              onClick={closeModal}
            ></div>

            {/* Modal panel */}
            <div className="relative bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all w-full max-w-lg z-10">
              <div className="bg-white px-6 pt-6 pb-4">
                <div className="sm:flex sm:items-start">
                  <div className="w-full">
                    <h3 className="text-2xl font-semibold text-slate-900 mb-2">
                      Submit for Production
                    </h3>
                    <p className="text-lg text-slate-600 mb-6">
                      Let's get this order underway.
                    </p>
                    <hr className="my-6 border-t-2 border-slate-200" />
                    <div className="text-sm text-slate-600 mb-6 space-y-3">
                      <div className="flex items-start space-x-3">
                        <SvgIcon
                          name="InfoIcon"
                          className="w-5 h-5 text-gray-600 mt-0.5 flex-shrink-0"
                        />
                        <p>
                          Making changes to your order after submitting may
                          carry an additional cost depending on the changes and
                          timing.
                        </p>
                      </div>
                      <div className="flex items-start space-x-3">
                        <SvgIcon
                          name="InfoIcon"
                          className="w-5 h-5 text-gray-600 mt-0.5 flex-shrink-0"
                        />
                        <p>
                          This order will be charged to the payment method
                          attached to your Framefox Pro account.
                        </p>
                      </div>
                    </div>

                    {/* Steps */}
                    {isSubmitting && (
                      <div className="space-y-4">
                        {Object.entries(steps).map(([key, step], index) => (
                          <div key={key} className="flex items-start space-x-3">
                            {getStepIcon(step.status)}
                            <div className="flex-1 min-w-0">
                              <p
                                className={`text-sm font-medium ${
                                  step.status === "error"
                                    ? "text-red-900"
                                    : step.status === "success"
                                    ? "text-green-900"
                                    : "text-slate-900"
                                }`}
                              >
                                {step.name}
                              </p>
                              {step.status === "error" &&
                                failedStep === index + 1 &&
                                error && (
                                  <p className="text-sm text-red-600 mt-1">
                                    {error}
                                  </p>
                                )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}

                    {/* General error message */}
                    {error && !isSubmitting && (
                      <div className="mt-6 p-4 bg-red-50 rounded-lg">
                        <p className="text-sm text-red-800">
                          <i className="fa-solid fa-exclamation-triangle mr-2"></i>
                          {error}
                        </p>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Footer */}
              <div className="bg-slate-50 px-6 py-4 sm:flex sm:flex-row-reverse">
                {!isSubmitting && !error && (
                  <button
                    onClick={handleSubmit}
                    disabled={isSubmitting}
                    className="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-slate-900 text-base font-medium text-white hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Confirm Submit
                  </button>
                )}
                <button
                  onClick={closeModal}
                  disabled={isSubmitting}
                  className="mt-3 w-full inline-flex justify-center rounded-md border border-slate-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-slate-700 hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 sm:mt-0 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isSubmitting ? "Processing..." : error ? "Close" : "Cancel"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

export default SubmitProductionButton;
