const state = {
  loading: false,
};

const $ = (id) => document.getElementById(id);
const number = (value) => new Intl.NumberFormat().format(value || 0);
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  "\"": "&quot;",
  "'": "&#39;",
})[char]);

function formatReset(value) {
  if (!value) return "未提供";
  const millis = typeof value === "number" ? value * 1000 : Date.parse(value);
  if (!Number.isFinite(millis)) return "未提供";
  return new Date(millis).toLocaleString();
}

function badge(text, kind = "") {
  return `<span class="badge ${kind}">${escapeHtml(text)}</span>`;
}

function windowRow(name, value) {
  if (!value) {
    return `<div class="window-row"><span>${name}</span><span class="muted">无数据</span></div>`;
  }
  return `
    <div class="window-row">
      <span>${name}</span>
      <span>${value.remaining_percent}% 剩余，${escapeHtml(formatReset(value.resets_at))} 重置</span>
    </div>
  `;
}

function renderProfile(profile) {
  const limits = profile.rate_limits || {};
  const primary = limits.primary;
  const secondary = limits.secondary;
  const authKind = profile.auth === "present" ? "ok" : "bad";
  const configKind = profile.config === "present" ? "ok" : "warn";
  const remoteKind = profile.remote_error ? "warn" : "ok";
  const plan = limits.plan_type || "unknown";
  const remaining = primary ? `${primary.remaining_percent}%` : "-";
  const credits = limits.credits_available ?? "-";

  return `
    <article class="profile-card">
      <div class="card-head">
        <div class="profile-name">${escapeHtml(profile.name)}</div>
      </div>
      <div class="badges">
        ${badge(`auth ${profile.auth}`, authKind)}
        ${badge(`config ${profile.config}`, configKind)}
        ${badge(profile.remote_error || "app-server ok", remoteKind)}
      </div>
      <div class="quota">
        <div>
          <span class="label">计划</span>
          <span class="value">${escapeHtml(plan)}</span>
        </div>
        <div>
          <span class="label">剩余额度</span>
          <span class="value">${remaining}</span>
        </div>
        <div>
          <span class="label">重置次数</span>
          <span class="value">${escapeHtml(credits)}</span>
        </div>
        <div>
          <span class="label">Limit</span>
          <span class="value">${escapeHtml(limits.limit_id || "-")}</span>
        </div>
      </div>
      <div class="windows">
        ${windowRow("主窗口", primary)}
        ${windowRow("次窗口", secondary)}
      </div>
      <div class="actions">
        <button class="primary" data-switch="${escapeHtml(profile.name)}" type="button">切换到这个账号</button>
      </div>
    </article>
  `;
}

function render(data) {
  $("sync-status").textContent = `同步时间 ${new Date(data.generated_at).toLocaleString()}`;
  $("profile-root").textContent = data.profile_root;
  $("thread-count").textContent = number(data.history?.thread_count);
  $("history-tokens").textContent = number(data.history?.tokens_used);
  $("input-tokens").textContent = number(data.local_snapshot?.total?.input_tokens);
  $("cached-tokens").textContent = number(data.local_snapshot?.total?.cached_input_tokens);
  $("output-tokens").textContent = number(data.local_snapshot?.total?.output_tokens);

  const profiles = data.profiles || [];
  $("profiles").innerHTML = profiles.length
    ? profiles.map(renderProfile).join("")
    : `<div class="empty">还没有 profile。先用命令行创建并登录账号。</div>`;

  document.querySelectorAll("[data-switch]").forEach((button) => {
    button.addEventListener("click", () => switchProfile(button.dataset.switch, button));
  });
}

async function refresh() {
  if (state.loading) return;
  state.loading = true;
  $("refresh").disabled = true;
  $("sync-status").textContent = "正在读取账号状态";
  try {
    const response = await fetch("/api/profiles");
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    render(await response.json());
  } catch (error) {
    $("sync-status").textContent = `读取失败：${error.message}`;
  } finally {
    state.loading = false;
    $("refresh").disabled = false;
  }
}

async function switchProfile(name, button) {
  button.disabled = true;
  button.textContent = "切换中";
  try {
    const response = await fetch("/api/switch", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({name}),
    });
    const payload = await response.json();
    if (!payload.ok) throw new Error(payload.error || `returncode ${payload.returncode}`);
    $("sync-status").textContent = `已切换到 ${name}`;
  } catch (error) {
    $("sync-status").textContent = `切换失败：${error.message}`;
  } finally {
    button.disabled = false;
    button.textContent = "切换到这个账号";
  }
}

$("refresh").addEventListener("click", refresh);
refresh();
