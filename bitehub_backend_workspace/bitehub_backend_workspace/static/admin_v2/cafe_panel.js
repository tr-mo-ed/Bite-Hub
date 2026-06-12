(function () {
  const configNode = document.getElementById("cafe-panel-config");
  if (!configNode) {
    return;
  }

  const config = JSON.parse(configNode.textContent || "{}");
  const wsIndicator = document.getElementById("wsIndicator");
  const confirmModalNode = document.getElementById("confirmCafePanelActionModal");
  const confirmTitle = document.getElementById("confirmCafePanelActionTitle");
  const confirmText = document.getElementById("confirmCafePanelActionText");
  const confirmSubmit = document.getElementById("confirmCafePanelActionSubmit");
  const confirmModal = confirmModalNode ? bootstrap.Modal.getOrCreateInstance(confirmModalNode) : null;

  function showToast(message, variant = "dark") {
    let stack = document.querySelector(".bh-toast-stack");
    if (!stack) {
      stack = document.createElement("div");
      stack.className = "bh-toast-stack";
      document.body.appendChild(stack);
    }

    const toast = document.createElement("div");
    toast.className = `toast bh-toast text-bg-${variant}`;
    toast.setAttribute("role", "alert");
    toast.setAttribute("aria-live", "assertive");
    toast.setAttribute("aria-atomic", "true");
    toast.innerHTML = `
      <div class="d-flex">
        <div class="toast-body fw-semibold">${message}</div>
        <button type="button" class="btn-close btn-close-white m-auto ms-2 me-2" data-bs-dismiss="toast" aria-label="Close"></button>
      </div>
    `;
    stack.appendChild(toast);
    const instance = bootstrap.Toast.getOrCreateInstance(toast, { delay: 3600 });
    toast.addEventListener("hidden.bs.toast", () => toast.remove());
    instance.show();
  }

  function confirmAction({ title, text }) {
    if (!confirmModal || !confirmSubmit) {
      return Promise.resolve(true);
    }
    if (confirmTitle) {
      confirmTitle.textContent = title || "تأكيد العملية";
    }
    if (confirmText) {
      confirmText.textContent = text || "هل تريد تنفيذ هذا الإجراء؟";
    }

    return new Promise((resolve) => {
      const cleanup = () => {
        confirmSubmit.removeEventListener("click", onConfirm);
        confirmModalNode.removeEventListener("hidden.bs.modal", onHidden);
      };
      const onConfirm = () => {
        cleanup();
        confirmModal.hide();
        resolve(true);
      };
      const onHidden = () => {
        cleanup();
        resolve(false);
      };
      confirmSubmit.addEventListener("click", onConfirm, { once: true });
      confirmModalNode.addEventListener("hidden.bs.modal", onHidden, { once: true });
      confirmModal.show();
    });
  }

  function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) {
      return parts.pop().split(";").shift();
    }
    return "";
  }

  function getCsrfToken() {
    return getCookie("csrftoken") || config.csrfToken;
  }

  function endpointFromTemplate(template, id) {
    return template.replace(/0\/$/, `${id}/`);
  }

  function showCafeSection(sectionName, { updateUrl = true } = {}) {
    const allowedSections = ["overview", "orders", "wallets", "nfc", "menu"];
    const activeSection = allowedSections.includes(sectionName) ? sectionName : "overview";
    document.querySelectorAll("[data-cafe-section-panel]").forEach((panel) => {
      panel.hidden = panel.dataset.cafeSectionPanel !== activeSection;
    });
    document.querySelectorAll("[data-cafe-section-link]").forEach((link) => {
      const isActive = link.dataset.section === activeSection;
      link.classList.toggle("active", isActive);
      link.classList.toggle("is-active", isActive);
      link.setAttribute("aria-current", isActive ? "page" : "false");
    });
    window.localStorage.setItem("bitehub:cafe-section", activeSection);
    if (updateUrl) {
      const nextHash = `#${activeSection}`;
      if (window.location.hash !== nextHash) {
        window.history.replaceState(null, "", nextHash);
      }
    }
  }

  function initialCafeSection() {
    const hash = window.location.hash.replace("#", "");
    return hash || window.localStorage.getItem("bitehub:cafe-section") || "overview";
  }

  document.addEventListener("click", (event) => {
    const sectionLink = event.target.closest("[data-cafe-section-link]");
    if (!sectionLink || !sectionLink.dataset.section) {
      return;
    }
    const linkUrl = new URL(sectionLink.href, window.location.origin);
    if (linkUrl.pathname !== window.location.pathname || linkUrl.search !== window.location.search) {
      return;
    }
    event.preventDefault();
    showCafeSection(sectionLink.dataset.section);
    window.scrollTo({ top: 0, behavior: "smooth" });
  });

  window.addEventListener("hashchange", () => {
    showCafeSection(initialCafeSection(), { updateUrl: false });
  });

  showCafeSection(initialCafeSection(), { updateUrl: false });

  function escapeHtml(value) {
    const span = document.createElement("span");
    span.textContent = value == null ? "" : String(value);
    return span.innerHTML;
  }

  function createOrderCard(order, nextStatus, nextLabel) {
    const items = (order.items || [])
      .map((item) => `
        <div class="line-item">
          <span>${escapeHtml(item.product_name || "منتج")}</span>
          <span class="line-qty">x${escapeHtml(item.quantity || 1)}</span>
        </div>
      `)
      .join("");
    const cancelButton = ["COMPLETED", "CANCELLED"].includes(order.status)
      ? ""
      : `<button type="button" class="btn btn-outline-danger btn-sm rounded-2 px-3 js-order-action order-secondary-action" data-order-id="${order.id}" data-status="CANCELLED">إلغاء</button>`;
    const createdAt = order.created_at
      ? new Date(order.created_at).toLocaleTimeString("ar-LY", { hour: "2-digit", minute: "2-digit" })
      : "";
    const customer = escapeHtml(order.user_name || order.user || "طالب");

    return `
      <article class="kanban-card order-ticket" data-order-id="${order.id}">
        <div class="order-ticket-head">
          <div>
            <div class="order-number">#${escapeHtml(order.order_number || order.id)}</div>
            <div class="meta">${createdAt} - ${customer}</div>
          </div>
          <span class="order-price">${escapeHtml(order.total_price || "0.00")} د.ل</span>
        </div>
        <div class="order-ticket-items">${items || '<div class="line-item text-muted">بدون عناصر مسجلة</div>'}</div>
        <div class="order-ticket-footer">
          ${nextStatus ? `<button type="button" class="btn btn-sm rounded-2 px-3 js-order-action order-primary-action" data-order-id="${order.id}" data-status="${nextStatus}">${escapeHtml(nextLabel)}</button>` : ""}
          ${cancelButton}
        </div>
      </article>
    `;
  }

  function statusMeta(status) {
    switch (status) {
      case "PENDING":
        return { column: "PENDING", nextStatus: "ACCEPTED", nextLabel: "قبول الطلب" };
      case "ACCEPTED":
        return { column: "PREPARING", nextStatus: "PREPARING", nextLabel: "بدء التجهيز" };
      case "PREPARING":
        return { column: "PREPARING", nextStatus: "READY", nextLabel: "إعلان الجاهزية" };
      case "READY":
        return { column: "READY", nextStatus: "COMPLETED", nextLabel: "إغلاق الطلب" };
      default:
        return { column: "", nextStatus: "", nextLabel: "" };
    }
  }

  function updateColumnCounts() {
    document.querySelectorAll(".kanban-column").forEach((column) => {
      const badge = column.querySelector(".badge");
      const body = column.querySelector(".order-column-body");
      if (!badge || !body) {
        return;
      }
      badge.textContent = body.querySelectorAll(".kanban-card").length;
    });
  }

  function clearOrderCards() {
    document.querySelectorAll(".kanban-card").forEach((card) => card.remove());
  }

  async function syncLatestOrders() {
    if (!config.snapshotEndpoint) {
      return;
    }

    try {
      const url = new URL(config.snapshotEndpoint, window.location.origin);
      url.searchParams.set("cafe_id", config.cafeId);
      const response = await fetch(url.toString(), {
        headers: { "Accept": "application/json" },
        credentials: "same-origin",
      });
      const payload = await response.json();
      if (!payload.success) {
        showToast(payload.message || "تعذر مزامنة الطلبات.", "danger");
        return;
      }

      clearOrderCards();
      (payload.orders || []).forEach((order) => upsertOrderCard(order, "snapshot.sync"));
      updateColumnCounts();
    } catch (error) {
      showToast("الاتصال غير مستقر. سيتم تحديث الطلبات عند عودة الشبكة.", "warning");
    }
  }

  function playBeep() {
    try {
      const context = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.type = "sine";
      oscillator.frequency.value = 880;
      gain.gain.value = 0.06;
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.start();
      oscillator.stop(context.currentTime + 0.18);
    } catch (error) {
      // Browsers may block audio before a user gesture.
    }
  }

  function upsertOrderCard(order, eventName) {
    const meta = statusMeta(order.status);
    const existing = document.querySelector(`.kanban-card[data-order-id="${order.id}"]`);
    if (existing) {
      existing.remove();
    }

    if (!meta.column) {
      updateColumnCounts();
      return;
    }

    const column = document.querySelector(`.kanban-column[data-status="${meta.column}"] .order-column-body`);
    if (!column) {
      updateColumnCounts();
      return;
    }

    column.querySelectorAll(".kanban-empty-state").forEach((node) => node.remove());
    column.insertAdjacentHTML("afterbegin", createOrderCard(order, meta.nextStatus, meta.nextLabel));
    if (eventName === "order.created") {
      playBeep();
    }
    updateColumnCounts();
  }

  async function postForm(url, body) {
    const encodedBody = body instanceof URLSearchParams
      ? body.toString()
      : new URLSearchParams(body).toString();
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "X-CSRFToken": getCsrfToken(),
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
      },
      body: encodedBody,
      credentials: "same-origin",
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.message || payload.error || "Request failed.");
    }
    return payload;
  }

  async function postMultipart(url, formData) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "X-CSRFToken": getCsrfToken(),
      },
      body: formData,
      credentials: "same-origin",
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.message || payload.error || "Request failed.");
    }
    return payload;
  }

  const productForm = document.getElementById("productForm");
  const resetProductForm = document.getElementById("resetProductForm");
  const walletOpsForm = document.getElementById("walletOpsForm");
  const walletOpsResult = document.getElementById("walletOpsResult");
  const cardBindForm = document.getElementById("cardBindForm");
  const cardBindResult = document.getElementById("cardBindResult");

  function resetProductEditor() {
    if (!productForm) {
      return;
    }
    productForm.reset();
    productForm.elements.product_id.value = "";
    productForm.elements.cafe_id.value = config.cafeId;
    productForm.elements.stock_quantity.value = "";
    productForm.elements.is_available.checked = true;
  }

  if (resetProductForm) {
    resetProductForm.addEventListener("click", resetProductEditor);
  }

  function writeResult(node, message, variant = "neutral") {
    if (!node) {
      return;
    }
    node.textContent = message;
    node.classList.toggle("text-success", variant === "success");
    node.classList.toggle("text-danger", variant === "danger");
  }

  if (walletOpsForm) {
    walletOpsForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      writeResult(walletOpsResult, "جاري تنفيذ العملية...");
      try {
        const payload = await postForm(config.walletOperationEndpoint, new FormData(walletOpsForm));
        const wallet = payload.wallet || {};
        writeResult(
          walletOpsResult,
          `تمت العملية: ${wallet.user || ""} | الرصيد الحالي ${wallet.balance || "0.00"} د.ل | الكود ${wallet.link_code || "-"}`,
          "success",
        );
        showToast("تم تحديث المحفظة.", "success");
        walletOpsForm.reset();
      } catch (error) {
        writeResult(walletOpsResult, error.message || "تعذر تنفيذ عملية المحفظة.", "danger");
        showToast(error.message || "تعذر تنفيذ عملية المحفظة.", "danger");
      }
    });
  }

  if (cardBindForm) {
    cardBindForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      writeResult(cardBindResult, "جاري ربط البطاقة...");
      try {
        const payload = await postForm(config.cardBindEndpoint, new FormData(cardBindForm));
        const wallet = payload.wallet || {};
        writeResult(
          cardBindResult,
          `تم ربط البطاقة ${wallet.nfc_card_uid || "-"} بمحفظة ${wallet.user || ""}.`,
          "success",
        );
        showToast("تم تعريف بطاقة الطالب.", "success");
        cardBindForm.reset();
      } catch (error) {
        writeResult(cardBindResult, error.message || "تعذر تعريف البطاقة.", "danger");
        showToast(error.message || "تعذر تعريف البطاقة.", "danger");
      }
    });
  }

  document.addEventListener("click", (event) => {
    const button = event.target.closest(".js-edit-product");
    if (!button || !productForm) {
      return;
    }

    productForm.elements.product_id.value = button.dataset.productId || "";
    productForm.elements.name.value = button.dataset.productName || "";
    productForm.elements.price.value = button.dataset.productPrice || "";
    productForm.elements.original_price.value = button.dataset.productOriginalPrice || "";
    productForm.elements.stock_quantity.value = button.dataset.productStock || "0";
    productForm.elements.category.value = button.dataset.productCategory || "";
    productForm.elements.description.value = button.dataset.productDescription || "";
    productForm.elements.is_available.checked = button.dataset.productAvailable === "true";
    productForm.scrollIntoView({ behavior: "smooth", block: "start" });
  });

  if (productForm) {
    productForm.addEventListener("submit", async (event) => {
      event.preventDefault();

      const productId = productForm.elements.product_id.value;
      const endpoint = productId
        ? endpointFromTemplate(config.saveProductEndpointTemplate, productId)
        : config.createProductEndpoint;
      const formData = new FormData(productForm);
      if (!productForm.elements.is_available.checked) {
        formData.set("is_available", "");
      }

      try {
        const payload = await postMultipart(endpoint, formData);
        if (!payload.success) {
          showToast(payload.message || "تعذر حفظ المنتج.", "danger");
          return;
        }
        showToast("تم حفظ المنتج. سيتم تحديث القائمة الآن.", "success");
        window.setTimeout(() => window.location.reload(), 550);
      } catch (error) {
        showToast(error.message || "تعذر حفظ المنتج.", "danger");
      }
    });
  }

  document.addEventListener("click", async (event) => {
    const button = event.target.closest(".js-order-action");
    if (!button) {
      return;
    }

    const orderId = button.dataset.orderId;
    const nextStatus = button.dataset.status;
    const confirmed = await confirmAction({
      title: "تأكيد تغيير حالة الطلب",
      text: `هل تريد نقل الطلب #${orderId} إلى ${nextStatus}؟`,
    });
    if (!confirmed) {
      return;
    }

    let payload;
    try {
      const endpoint = endpointFromTemplate(config.statusEndpointTemplate, orderId);
      payload = await postForm(endpoint, {
        cafe_id: config.cafeId,
        status: nextStatus,
      });
    } catch (error) {
      showToast(error.message || "انقطع الاتصال أثناء تحديث الطلب.", "danger");
      return;
    }

    if (!payload.success) {
      showToast(payload.message || "فشل تحديث الطلب.", "danger");
      return;
    }

    upsertOrderCard(payload.order, "order.updated");
    showToast("تم تحديث حالة الطلب بنجاح.", "success");
  });

  document.querySelectorAll(".js-stock-toggle").forEach((input) => {
    input.addEventListener("change", async () => {
      const desiredState = input.checked;
      const confirmed = await confirmAction({
        title: "تأكيد تحديث المخزون",
        text: `${desiredState ? "تفعيل" : "إيقاف"} توفر ${input.dataset.productName || "المنتج"}؟`,
      });
      if (!confirmed) {
        input.checked = !desiredState;
        return;
      }

      let payload;
      try {
        const endpoint = endpointFromTemplate(config.stockEndpointTemplate, input.dataset.productId);
        payload = await postForm(endpoint, {
          cafe_id: config.cafeId,
          is_available: desiredState ? "true" : "false",
        });
      } catch (error) {
        input.checked = !desiredState;
        showToast(error.message || "انقطع الاتصال أثناء تحديث المخزون.", "danger");
        return;
      }
      if (!payload.success) {
        input.checked = !desiredState;
        showToast(payload.message || "تعذر تحديث المخزون.", "danger");
        return;
      }
      showToast("تم تحديث حالة المنتج.", "success");
    });
  });

  let socket = null;
  let reconnectTimer = null;
  let pollingTimer = null;
  let reconnectDelay = 1500;

  function startPollingFallback() {
    if (pollingTimer) {
      return;
    }
    pollingTimer = window.setInterval(syncLatestOrders, 8000);
  }

  function connectSocket() {
    if (socket && [WebSocket.OPEN, WebSocket.CONNECTING].includes(socket.readyState)) {
      return;
    }

    const protocol = window.location.protocol === "https:" ? "wss" : "ws";
    socket = new WebSocket(`${protocol}://${window.location.host}${config.wsPath}`);

    socket.addEventListener("open", () => {
      reconnectDelay = 1500;
      if (wsIndicator) {
        wsIndicator.classList.add("connected");
      }
      syncLatestOrders();
      startPollingFallback();
    });

    socket.addEventListener("close", () => {
      if (wsIndicator) {
        wsIndicator.classList.remove("connected");
      }
      startPollingFallback();
      reconnectTimer = window.setTimeout(connectSocket, reconnectDelay);
      reconnectDelay = Math.min(reconnectDelay * 2, 15000);
    });

    socket.addEventListener("error", () => {
      if (socket) {
        socket.close();
      }
    });

    socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data || "{}");
      if (!message.payload) {
        return;
      }
      upsertOrderCard(message.payload, message.event);
    });
  }

  window.addEventListener("online", () => {
    window.clearTimeout(reconnectTimer);
    connectSocket();
    syncLatestOrders();
  });

  window.addEventListener("offline", () => {
    if (wsIndicator) {
      wsIndicator.classList.remove("connected");
    }
    showToast("انقطع الاتصال. سيتم مزامنة الطلبات عند عودة الشبكة.", "warning");
  });

  connectSocket();
  startPollingFallback();
  syncLatestOrders();
})();
