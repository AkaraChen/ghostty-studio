// @vitest-environment jsdom
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ConfirmationDialog } from "./components/ConfirmationDialog";

describe("application confirmation dialog", () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean })
      .IS_REACT_ACT_ENVIRONMENT = true;
    container = document.createElement("div");
    document.body.append(container);
    root = createRoot(container);
  });

  afterEach(() => {
    act(() => root.unmount());
    container.remove();
  });

  it("renders the backend title and multiline message unchanged", () => {
    const message = "将保存 1 项修改：font-size。\n\n保存前会自动创建快照。";
    act(() => root.render(
      <ConfirmationDialog
        prompt={{ title: "写入配置", message }}
        processing={false}
        onCancel={() => undefined}
        onConfirm={() => undefined}
      />,
    ));

    const dialog = container.querySelector<HTMLElement>('[role="dialog"]')!;
    expect(dialog.getAttribute("aria-modal")).toBe("true");
    expect(container.querySelector("h2")?.textContent).toBe("写入配置");
    expect(container.querySelector(".confirmation-message")?.textContent).toBe(message);
    expect(document.activeElement?.textContent).toBe("取消");
  });

  it("cancels with Escape and suppresses duplicate confirmation", () => {
    const onCancel = vi.fn();
    const onConfirm = vi.fn();
    act(() => root.render(
      <ConfirmationDialog
        prompt={{ title: "恢复快照", message: "trusted" }}
        processing={false}
        onCancel={onCancel}
        onConfirm={onConfirm}
      />,
    ));

    const confirm = [...container.querySelectorAll<HTMLButtonElement>("button")]
      .find((button) => button.textContent === "恢复快照")!;
    act(() => {
      confirm.click();
      confirm.click();
    });
    expect(onConfirm).toHaveBeenCalledTimes(1);

    act(() => document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" })));
    expect(onCancel).toHaveBeenCalledTimes(1);
  });

  it("disables both choices while processing", () => {
    act(() => root.render(
      <ConfirmationDialog
        prompt={{ title: "创建配置", message: "trusted" }}
        processing
        onCancel={() => undefined}
        onConfirm={() => undefined}
      />,
    ));
    expect([...container.querySelectorAll<HTMLButtonElement>("button")].every((button) => button.disabled)).toBe(true);
    expect(container.textContent).toContain("处理中…");
  });
});
