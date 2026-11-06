(() => {
  "use strict";

  const base = "http://127.0.0.1:9876";
  const root = document.documentElement;
  const snapshotId = root.dataset.snapshotId || "";
  const status = document.getElementById("load-status");
  const producerHeader = document.getElementById("producer-header");
  const summary = document.getElementById("summary");
  const flowRows = document.getElementById("flow-rows");
  const sourceEvents = document.getElementById("source-events");
  const findingsHost = document.getElementById("findings");
  const limitationsHost = document.getElementById("limitations");

  function node(tag, className, value) {
    const result = document.createElement(tag);
    if (className) result.className = className;
    if (value !== undefined && value !== null) result.textContent = String(value);
    return result;
  }

  function field(host, label, value, className) {
    if (value === undefined || value === null || value === "") return;
    const wrapper = node("div", "field");
    wrapper.append(node("span", "field-label", label));
    if (typeof value === "object") {
      wrapper.append(node("pre", "json", JSON.stringify(value, null, 2)));
    } else if (typeof value === "string" && (value.includes("\n") || /command|argument|context|evidence|output/i.test(label))) {
      const kind = /diff --git|^@@ /m.test(value) ? "diff" : (/command|argument/i.test(label) ? "command" : "");
      wrapper.append(node("pre", kind, value));
    } else {
      wrapper.append(node("div", className || "", value));
    }
    host.append(wrapper);
  }

  function sourceField(host, label, source, events) {
    if (!source) return;
    const wrapper = node("div", "field");
    wrapper.append(node("span", "field-label", label));
    const event = events.find((item) => item.Source && (source === item.Source || source.startsWith(`${item.Source};`)));
    const index = event ? Number(event.Index) : NaN;
    const href = Number.isInteger(index)
      ? `${base}/failure-analysis/${snapshotId}/index.html#event-${index}`
      : `${base}/failure-analysis/${snapshotId}/report.json`;
    const link = node("a", "citation", source);
    link.href = href;
    wrapper.append(link);
    host.append(wrapper);
  }

  function addArgumentStrings(host, value, path) {
    if (typeof value === "string") {
      if (value.includes("\n") || /diff --git|^@@ /m.test(value)) {
        const detail = node("details");
        detail.append(node("summary", "", path));
        const kind = /diff --git|^@@ /m.test(value) ? "diff" : (/command|shell/i.test(path) ? "command" : "");
        detail.append(node("pre", kind, value));
        host.append(detail);
      }
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((item, index) => addArgumentStrings(host, item, `${path}[${index}]`));
    } else if (value && typeof value === "object") {
      Object.keys(value).forEach((key) => addArgumentStrings(host, value[key], path ? `${path}.${key}` : key));
    }
  }

  function argumentField(host, args) {
    if (args === undefined || args === null) return;
    const wrapper = node("div", "field");
    wrapper.append(node("span", "field-label", "Full arguments"));
    if (typeof args === "object") wrapper.append(node("pre", "json", JSON.stringify(args, null, 2)));
    else wrapper.append(node("pre", /diff --git|^@@ /m.test(String(args)) ? "diff" : "command", args));
    addArgumentStrings(wrapper, args, "arguments");
    host.append(wrapper);
  }

  function metric(label, value, variant) {
    const card = node("div", `metric ${variant || ""}`);
    card.append(node("strong", "", value));
    card.append(node("span", "", label));
    summary.append(card);
  }

  function renderFlow(entries, events) {
    if (!entries.length) {
      flowRows.append(node("tr", "", ""));
      flowRows.lastChild.append(node("td", "empty", "No tool-start metadata was retained."));
      flowRows.lastChild.firstChild.colSpan = 4;
      return;
    }
    entries.forEach((entry) => {
      const row = node("tr");
      row.append(node("td", "", entry.Tool || "Unknown tool"));
      row.append(node("td", "", entry.Outcome || "Unknown"));
      const sourceCell = node("td");
      sourceField(sourceCell, "Source", entry.Source, events);
      if (!entry.Source) sourceCell.textContent = "Source unavailable";
      row.append(sourceCell);
      const detailsCell = node("td");
      const details = node("details");
      details.append(node("summary", "", "Expand"));
      const body = node("div", "detail-body");
      field(body, "User request / context", entry.Request);
      field(body, "Recorded stated purpose", entry.Purpose);
      field(body, "Preceding assistant context", entry.AssistantContext);
      field(body, "Relationship and limits", entry.Relationship);
      field(body, "Call / turn / parent IDs", [entry.CallId, entry.TurnId, entry.ParentId].filter(Boolean).join(" / "));
      sourceField(body, "Source citation", entry.Source, events);
      argumentField(body, entry.Arguments);
      details.append(body);
      detailsCell.append(details);
      row.append(detailsCell);
      flowRows.append(row);
    });
  }

  function renderFindings(entries, events) {
    if (!entries.length) {
      findingsHost.append(node("p", "empty", "No classified findings were retained."));
      return;
    }
    entries.forEach((finding, index) => {
      const detail = node("details");
      detail.append(node("summary", "", `${finding.Disposition || "Finding"} — ${finding.Category || "Unclassified"} (${index + 1})`));
      const body = node("div", "detail-body");
      sourceField(body, "Source citation", finding.Source, events);
      field(body, "Recorded event time", finding.Timestamp);
      field(body, "Call ID / exit status", [finding.CallId, finding.ExitStatus].filter(Boolean).join(" / "));
      field(body, "Evidence text", finding.Evidence);
      field(body, "Numbered output context", Array.isArray(finding.Context) ? finding.Context.join("\n") : finding.Context);
      field(body, "Runtime locations", Array.isArray(finding.Locations) ? finding.Locations.join("\n") : finding.Locations);
      field(body, "Corroborating logs", Array.isArray(finding.Related) ? finding.Related.join("\n") : finding.Related);
      field(body, "Investigation / countermeasure", finding.Advice);
      argumentField(body, finding.Command);
      detail.append(body);
      findingsHost.append(detail);
    });
  }

  function renderSourceEvents(entries) {
    if (!entries.length) {
      sourceEvents.append(node("p", "empty", "No normalized source events were retained."));
      return;
    }
    entries.forEach((event) => {
      const index = Number(event.Index);
      const detail = node("details");
      if (Number.isInteger(index)) detail.id = `event-${index}`;
      detail.append(node("summary", "", `${event.Role || "event"} / ${event.Tool || event.Type || "unknown"} — ${event.Source || "source unavailable"}`));
      const body = node("div", "detail-body");
      field(body, "Event identity", [event.Id, event.Type, event.CallId, event.TurnId, event.ParentId].filter(Boolean).join(" / "));
      field(body, "Recorded timestamp", event.Timestamp);
      sourceField(body, "Source citation", event.Source, entries);
      field(body, "Complete event text", event.Text);
      argumentField(body, event.Arguments);
      detail.append(body);
      sourceEvents.append(detail);
    });
  }

  async function load() {
    if (!/^[a-f0-9]{32}$/.test(snapshotId)) throw new Error("Invalid snapshot identifier.");
    producerHeader.textContent = "Producer not recorded";
    if (root.dataset.hasJson !== "true") {
      status.textContent = "Legacy Markdown snapshot only; structured execution evidence was unavailable and has not been reconstructed.";
      return;
    }
    const response = await fetch(`${base}/failure-analysis/${snapshotId}/report.json`, { cache: "no-store" });
    if (!response.ok) throw new Error(`The daemon could not serve report.json (HTTP ${response.status}).`);
    const report = await response.json();
    if (report.Schema !== "LCM.FailureAnalysis" || report.SchemaVersion !== 1) {
      throw new Error("Unsupported structured report schema.");
    }
    const counts = report.Summary || {};
    const producerName = typeof report.Producer === "string" && report.Producer.trim()
      ? report.Producer
      : "Producer not recorded";
    const producerVersion = typeof report.ProducerVersion === "string" && report.ProducerVersion.trim()
      ? report.ProducerVersion
      : "Producer not recorded";
    producerHeader.textContent = `${producerName} / version ${producerVersion}`;
    field(summary, "Producer", producerName);
    field(summary, "Producer version", producerVersion);
    metric("Confirmed findings", counts.Confirmed ?? 0, "confirmed");
    metric("Unresolved evidence", counts.Unresolved ?? 0, "unresolved");
    metric("Selected events", counts.EventCount ?? 0);
    metric("Anchor matches", counts.AnchorMatches ?? 0);
    field(summary, "Generated", report.GeneratedAt);
    field(summary, "Host / session", [report.Host, report.SessionId].filter(Boolean).join(" / "));
    field(summary, "Source", report.Source, "citation");
    field(summary, "Selected anchor", report.Selection && report.Selection.Anchor);
    const events = Array.isArray(report.Events) ? report.Events : [];
    renderSourceEvents(events);
    renderFlow(Array.isArray(report.ExecutionFlow) ? report.ExecutionFlow : [], events);
    renderFindings(Array.isArray(report.Findings) ? report.Findings : [], events);
    (Array.isArray(report.Limitations) ? report.Limitations : []).forEach((item) => limitationsHost.append(node("li", "", item)));
    status.textContent = "Retained evidence loaded. The report is a snapshot and does not rerun analysis.";
  }

  load().catch((error) => {
    status.className = "error";
    status.textContent = `Evidence display failed: ${error.message}`;
  });
})();
