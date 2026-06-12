(function () {
  let pendingCafeToggleForm = null;
  const confirmCafeToggleModalNode = document.getElementById("confirmCafeToggleModal");
  const confirmCafeToggleText = document.getElementById("confirmCafeToggleText");
  const confirmCafeToggleSubmit = document.getElementById("confirmCafeToggleSubmit");
  const confirmCafeToggleModal = confirmCafeToggleModalNode
    ? bootstrap.Modal.getOrCreateInstance(confirmCafeToggleModalNode)
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

      const cafeName = pendingCafeToggleForm.dataset.cafeName || "هذا المقهى";
      const nextAction = pendingCafeToggleForm.dataset.nextAction || "تغيير حالة";
      if (confirmCafeToggleText) {
        confirmCafeToggleText.textContent = `هل تريد ${nextAction} ${cafeName}؟`;
      }
      confirmCafeToggleModal.show();
    });
  });

  confirmCafeToggleSubmit?.addEventListener("click", () => {
    if (pendingCafeToggleForm) {
      submitWithFreshCsrf(pendingCafeToggleForm);
    }
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
        resetCafePasswordSubtitle.textContent = `تغيير كلمة مرور ${button.dataset.cafeName || "المقهى"}.`;
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
          label: "المبيعات",
          data: sales,
          tension: 0.35,
          borderColor: "#4357b8",
          backgroundColor: "rgba(67, 87, 184, 0.16)",
          fill: true,
          yAxisID: "y",
        },
        {
          label: "الطلبات",
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
