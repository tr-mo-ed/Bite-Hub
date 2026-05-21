(function () {
  let pendingCafeToggleForm = null;
  let pendingCafeDeleteForm = null;
  let pendingCafeDeleteCode = "";

  const confirmCafeToggleModalNode = document.getElementById("confirmCafeToggleModal");
  const confirmCafeToggleText = document.getElementById("confirmCafeToggleText");
  const confirmCafeToggleSubmit = document.getElementById("confirmCafeToggleSubmit");
  const confirmCafeToggleModal = confirmCafeToggleModalNode
    ? bootstrap.Modal.getOrCreateInstance(confirmCafeToggleModalNode)
    : null;

  const confirmCafeDeleteModalNode = document.getElementById("confirmCafeDeleteModal");
  const confirmCafeDeleteText = document.getElementById("confirmCafeDeleteText");
  const confirmCafeDeleteHint = document.getElementById("confirmCafeDeleteHint");
  const confirmCafeDeleteInput = document.getElementById("confirmCafeDeleteInput");
  const confirmCafeDeleteSubmit = document.getElementById("confirmCafeDeleteSubmit");
  const confirmCafeDeleteModal = confirmCafeDeleteModalNode
    ? bootstrap.Modal.getOrCreateInstance(confirmCafeDeleteModalNode)
    : null;

  function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
      return parts.pop().split(";").shift();
    }
    return "";
  }

  function submitWithFreshCsrf(form) {
    const token = getCookie("csrftoken");
    const input = form.querySelector("input[name='csrfmiddlewaretoken']");
    if (token && input) {
      input.value = token;
    }
    form.submit();
  }

  document.querySelectorAll(".js-toggle-cafe-button").forEach((button) => {
    button.addEventListener("click", () => {
      pendingCafeToggleForm = button.closest(".js-toggle-cafe-form");
      if (!pendingCafeToggleForm || !confirmCafeToggleModal) {
        if (pendingCafeToggleForm) {
          submitWithFreshCsrf(pendingCafeToggleForm);
        }
        return;
      }

      const cafeName = pendingCafeToggleForm.dataset.cafeName || "\u0647\u0630\u0627 \u0627\u0644\u0645\u0642\u0647\u0649";
      const nextAction = pendingCafeToggleForm.dataset.nextAction || "\u062a\u063a\u064a\u064a\u0631 \u062d\u0627\u0644\u0629";
      if (confirmCafeToggleText) {
        confirmCafeToggleText.textContent = `\u0647\u0644 \u062a\u0631\u064a\u062f ${nextAction} ${cafeName}\u061f`;
      }
      confirmCafeToggleModal.show();
    });
  });

  confirmCafeToggleSubmit?.addEventListener("click", () => {
    if (pendingCafeToggleForm) {
      submitWithFreshCsrf(pendingCafeToggleForm);
    }
  });

  function updateDeleteSubmitState() {
    if (!confirmCafeDeleteSubmit || !confirmCafeDeleteInput) {
      return;
    }
    confirmCafeDeleteSubmit.disabled = confirmCafeDeleteInput.value.trim() !== pendingCafeDeleteCode;
  }

  document.querySelectorAll(".js-delete-cafe-button").forEach((button) => {
    button.addEventListener("click", () => {
      pendingCafeDeleteForm = button.closest(".js-delete-cafe-form");
      if (!pendingCafeDeleteForm || !confirmCafeDeleteModal) {
        return;
      }

      pendingCafeDeleteCode = pendingCafeDeleteForm.dataset.cafeCode || "";
      const cafeName = pendingCafeDeleteForm.dataset.cafeName || "\u0647\u0630\u0627 \u0627\u0644\u0645\u0642\u0647\u0649";
      if (confirmCafeDeleteText) {
        confirmCafeDeleteText.textContent = `\u0633\u064a\u062a\u0645 \u062d\u0630\u0641 ${cafeName} \u0646\u0647\u0627\u0626\u064a\u0627\u064b \u0645\u0646 \u0627\u0644\u0646\u0638\u0627\u0645.`;
      }
      if (confirmCafeDeleteHint) {
        confirmCafeDeleteHint.textContent = `\u0627\u0644\u0643\u0648\u062f \u0627\u0644\u0645\u0637\u0644\u0648\u0628: ${pendingCafeDeleteCode}`;
      }
      if (confirmCafeDeleteInput) {
        confirmCafeDeleteInput.value = "";
      }
      updateDeleteSubmitState();
      confirmCafeDeleteModal.show();
      window.setTimeout(() => {
        confirmCafeDeleteInput?.focus();
      }, 200);
    });
  });

  confirmCafeDeleteInput?.addEventListener("input", updateDeleteSubmitState);

  confirmCafeDeleteSubmit?.addEventListener("click", () => {
    if (!pendingCafeDeleteForm || confirmCafeDeleteSubmit.disabled) {
      return;
    }
    const confirmationInput = pendingCafeDeleteForm.querySelector("input[name='confirmation']");
    if (confirmationInput && confirmCafeDeleteInput) {
      confirmationInput.value = confirmCafeDeleteInput.value.trim();
    }
    submitWithFreshCsrf(pendingCafeDeleteForm);
  });

  const generatedCafePassword = document.getElementById("generatedCafePassword");
  const generateCafePassword = document.getElementById("generateCafePassword");
  const resetCafePasswordForm = document.getElementById("resetCafePasswordForm");
  const resetCafePasswordInput = document.getElementById("resetCafePasswordInput");
  const resetCafePasswordSubtitle = document.getElementById("resetCafePasswordSubtitle");
  const generateResetCafePassword = document.getElementById("generateResetCafePassword");
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

  function randomPassword() {
    const bytes = new Uint32Array(14);
    if (window.crypto?.getRandomValues) {
      window.crypto.getRandomValues(bytes);
    } else {
      for (let index = 0; index < bytes.length; index += 1) {
        bytes[index] = Math.floor(Math.random() * alphabet.length);
      }
    }
    const value = Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
    return `BH-${value.slice(0, 4)}-${value.slice(4, 9)}-${value.slice(9)}`;
  }

  generateCafePassword?.addEventListener("click", () => {
    if (!generatedCafePassword) {
      return;
    }
    generatedCafePassword.value = randomPassword();
    generatedCafePassword.focus();
    generatedCafePassword.select();
  });

  document.querySelectorAll(".js-open-password-modal").forEach((button) => {
    button.addEventListener("click", () => {
      if (resetCafePasswordForm) {
        resetCafePasswordForm.action = button.dataset.action || "";
      }
      if (resetCafePasswordSubtitle) {
        resetCafePasswordSubtitle.textContent = `\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0645\u0631\u0648\u0631 ${button.dataset.cafeName || "\u0627\u0644\u0645\u0642\u0647\u0649"}.`;
      }
      if (resetCafePasswordInput) {
        resetCafePasswordInput.value = randomPassword();
        window.setTimeout(() => {
          resetCafePasswordInput.focus();
          resetCafePasswordInput.select();
        }, 200);
      }
    });
  });

  generateResetCafePassword?.addEventListener("click", () => {
    if (!resetCafePasswordInput) {
      return;
    }
    resetCafePasswordInput.value = randomPassword();
    resetCafePasswordInput.focus();
    resetCafePasswordInput.select();
  });

  const node = document.getElementById("sales-series-data");
  const canvas = document.getElementById("salesTrendChart");
  if (!node || !canvas || typeof Chart === "undefined") {
    return;
  }

  const raw = JSON.parse(node.textContent || "[]");
  const labels = raw.map((entry) => entry.label);
  const sales = raw.map((entry) => entry.sales);
  const orders = raw.map((entry) => entry.orders);

  new Chart(canvas, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "\u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a",
          data: sales,
          tension: 0.35,
          borderColor: "#4357b8",
          backgroundColor: "rgba(67, 87, 184, 0.16)",
          fill: true,
          yAxisID: "y",
        },
        {
          label: "\u0627\u0644\u0637\u0644\u0628\u0627\u062a",
          data: orders,
          tension: 0.35,
          borderColor: "#f51f2e",
          backgroundColor: "rgba(255, 122, 26, 0.14)",
          yAxisID: "y1",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          labels: {
            usePointStyle: true,
          },
        },
      },
      scales: {
        y: {
          beginAtZero: true,
          grid: {
            color: "rgba(67, 87, 184, 0.13)",
          },
        },
        y1: {
          beginAtZero: true,
          position: "right",
          grid: {
            drawOnChartArea: false,
          },
        },
        x: {
          grid: {
            display: false,
          },
        },
      },
    },
  });
})();
