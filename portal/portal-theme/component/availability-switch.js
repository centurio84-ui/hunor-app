/* <hunor-availability-switch>: encapsulated shared UI, inherits theme variables. */
(function () {
  "use strict";
  var scriptURL = document.currentScript.src;
  var cssURL = new URL("./availability-switch.css", scriptURL).href;
  var labels = { ready:"Riasztható", unavailable:"Nem riasztható", unset:"Korlátozott / Nincs beállítva" };
  class AvailabilitySwitch extends HTMLElement {
    static get observedAttributes() { return ["value","disabled","locked"]; }
    constructor() {
      super();
      this._unsubscribe = null;
      this._feedback = "";
      this._feedbackKind = "";
      this._reflecting = false;
      this._provider = null;
      this._core = HunorAvailabilityCore.create({value:"unset"});
      this.attachShadow({mode:"open"});
      this.shadowRoot.innerHTML = '<link rel="stylesheet"><section class="card" aria-labelledby="heading"><div class="head"><span class="icon" aria-hidden="true"><svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="18"/><circle cx="20" cy="14" r="6"/><path d="M9 32v-2a11 11 0 0 1 22 0v2"/></svg></span><div class="copy"><h2 id="heading">Saját riaszthatóság</h2><p class="description">Válassz állapotot egy kattintással.</p></div><span class="badge"><span class="indicator" aria-hidden="true"></span><span class="badge-label"></span></span></div><div class="options" role="group" aria-label="Riaszthatósági állapot"><button type="button" data-value="ready" aria-pressed="false"><span class="mark" aria-hidden="true"></span>Riasztható</button><button type="button" data-value="unavailable" aria-pressed="false"><span class="mark" aria-hidden="true"></span>Nem riasztható</button><button type="button" data-value="unset" aria-pressed="false"><span class="mark" aria-hidden="true"></span>Korlátozott / Nincs beállítva</button></div><p class="feedback" role="status" aria-live="polite" aria-atomic="true"></p></section>';
      this.shadowRoot.querySelector("link").href = cssURL;
      this.shadowRoot.addEventListener("click", (event) => {
        var button = event.target.closest("button[data-value]");
        if (button && !button.disabled) this._core.request(button.dataset.value);
      });
    }
    connectedCallback() {
      if (!this._unsubscribe) this._unsubscribe = this._core.subscribe((event) => this._onEvent(event));
      if (this.hasAttribute("value")) this._core.setValue(this.getAttribute("value"));
      this._applyPolicy();
      this._render();
    }
    disconnectedCallback() {
      if (this._unsubscribe) this._unsubscribe();
      this._unsubscribe = null;
      /* Ignore late responses after this view has been removed. */
      this._core.setProvider(this._provider);
    }
    attributeChangedCallback(name, oldValue, newValue) {
      if (oldValue === newValue || this._reflecting) return;
      if (name === "value" && newValue !== null) this._core.setValue(newValue);
      if (name === "disabled" || name === "locked") this._applyPolicy();
    }
    get value() { return this._core.snapshot().value; }
    set value(value) {
      HunorAvailabilityCore.validate(value);
      this._core.setValue(value);
      this._feedback = ""; this._render();
    }
    configure(options) {
      options = options || {};
      if (Object.prototype.hasOwnProperty.call(options,"save")) {
        this._provider = options.save;
        this._core.setProvider(options.save);
      }
      if (Object.prototype.hasOwnProperty.call(options,"value")) this.value = options.value;
      this._applyPolicy(); this._render();
      return this;
    }
    _applyPolicy() { this._core.setEnabled(!this.hasAttribute("disabled") && !this.hasAttribute("locked")); }
    _onEvent(event) {
      if (event.type === "pending") { this._feedback = "Mentés…"; this._feedbackKind = ""; }
      if (event.type === "saved") {
        this._feedback = "Állapot mentve: " + labels[event.value] + ".";
        this._feedbackKind = "";
        this.dispatchEvent(new CustomEvent("hunor:availabilitychange",{bubbles:true,composed:true,detail:{value:event.value}}));
      }
      if (event.type === "error") {
        this._feedback = event.error && event.error.message ? event.error.message : "Nem sikerült menteni. Az előző állapot megmaradt.";
        this._feedbackKind = "error";
        this.dispatchEvent(new CustomEvent("hunor:availabilityerror",{bubbles:true,composed:true,detail:{error:event.error}}));
      }
      if (event.type === "sync" || event.type === "policy") { this._feedback = ""; this._feedbackKind = ""; }
      if (event.type === "settled" && this._feedback === "Mentés…") this._feedback = "";
      this._render();
    }
    _render() {
      if (!this.shadowRoot) return;
      var state = this._core.snapshot();
      this._reflecting = true;
      this.setAttribute("value",state.value);
      this._reflecting = false;
      var card = this.shadowRoot.querySelector(".card");
      card.dataset.state = state.value;
      card.setAttribute("aria-busy",String(state.busy));
      this.shadowRoot.querySelector(".badge-label").textContent = labels[state.value];
      this.shadowRoot.querySelectorAll("button").forEach((button) => {
        button.setAttribute("aria-pressed",String(button.dataset.value === state.value));
        button.disabled = state.busy || !state.enabled;
      });
      var feedback = this.shadowRoot.querySelector(".feedback");
      feedback.textContent = this.hasAttribute("locked") ? "Az állapot zárolt. Felülvizsgálathoz keresd a jogosult kezelőt." : this._feedback;
      feedback.dataset.kind = this._feedbackKind;
    }
  }
  if (!customElements.get("hunor-availability-switch")) customElements.define("hunor-availability-switch",AvailabilitySwitch);
})();
