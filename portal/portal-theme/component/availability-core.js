/* HUNOR availability switch state model. Browser + Node, no dependencies. */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.HunorAvailabilityCore = factory();
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  var values = Object.freeze(["ready", "unavailable", "unset"]);
  function validate(value) {
    if (!values.includes(value)) throw new RangeError("Ismeretlen riaszthatósági állapot: " + String(value));
    return value;
  }
  function create(options) {
    options = options || {};
    var current = validate(options.value === undefined ? "unset" : options.value);
    var save = options.save || null;
    var enabled = options.enabled !== false, busy = false, version = 0;
    var subscribers = new Set();
    function snapshot() { return Object.freeze({ value: current, busy: busy, enabled: enabled }); }
    function emit(type, extra) {
      var event = Object.assign({ type: type }, snapshot(), extra || {});
      subscribers.forEach(function (fn) { fn(event); });
    }
    return Object.freeze({
      snapshot: snapshot,
      subscribe: function (listener) {
        if (typeof listener !== "function") throw new TypeError("A figyelő függvény legyen.");
        subscribers.add(listener);
        return function () { subscribers.delete(listener); };
      },
      setProvider: function (provider) {
        if (provider !== null && typeof provider !== "function") throw new TypeError("A mentési adapter függvény legyen.");
        version++; save = provider;
      },
      setEnabled: function (next) {
        next = Boolean(next);
        if (next !== enabled) { version++; enabled = next; emit("policy"); }
      },
      setValue: function (value) {
        validate(value);
        version++; current = value; emit("sync");
      },
      request: async function (next) {
        validate(next);
        if (!enabled) return { ok: false, reason: "disabled", value: current };
        if (busy) return { ok: false, reason: "busy", value: current };
        if (next === current) return { ok: true, unchanged: true, value: current };
        if (!save) {
          var missing = new Error("Ehhez a kártyához még nincs mentési adapter bekötve.");
          emit("error", { error: missing });
          return { ok: false, reason: "missing-provider", error: missing, value: current };
        }
        var ticket = ++version;
        var provider = save;
        busy = true; emit("pending", { requested: next });
        try {
          var result = await provider(next, { previous: current });
          if (ticket !== version) return { ok: false, reason: "superseded", value: current };
          if (!result || !values.includes(result.value)) throw new Error("A mentés nem igazolt vissza érvényes állapotot.");
          current = result.value;
          emit("saved");
          return { ok: true, value: current };
        } catch (error) {
          if (ticket === version) emit("error", { error: error });
          return { ok: false, reason: ticket === version ? "save" : "superseded", error: error, value: current };
        } finally {
          busy = false; emit("settled");
        }
      }
    });
  }
  return Object.freeze({ values: values, validate: validate, create: create });
});
