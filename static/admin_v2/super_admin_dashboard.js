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
