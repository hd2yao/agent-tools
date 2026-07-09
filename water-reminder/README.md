# 喝水提醒小飞机

一个 macOS 本机小工具：每 15 分钟弹出一个紧凑置顶提醒，小飞机从屏幕左侧慢慢飞到中间，提示“太辛苦了！快去喝水！”。它会停在中间，等你点击真正的系统按钮“知道了”后再飞走。

窗口只覆盖飞机、提示牌和确认按钮这一小块区域，不再使用全屏透明窗口。飞机在右侧前方，提示牌在左侧后方，由飞机拖着走；图案使用克制的折纸小飞机，没有水滴尾迹或复杂装饰，避免影响主要提醒。

## 效果展示

等待态的视觉层级固定为：提示文案最先被看到，确认按钮在提示牌下方，小飞机在右侧前方作为牵引图案。按钮是唯一可点区域，透明背景不会挡住其他应用。

不安装系统服务的预览命令：

```bash
swift water_reminder.swift --once --display-seconds 1 --auto-confirm-seconds 4 --exit-seconds 1
```

## 使用

预览一次：

```bash
cd /Users/dysania/program/tools/agent-tools/water-reminder
swift water_reminder.swift --once
```

安装并开始长期提醒：

```bash
cd /Users/dysania/program/tools/agent-tools/water-reminder
./install-launch-agent.sh
```

启动后会立即提醒一次，之后每 15 分钟提醒一次。停止并卸载时运行：

```bash
cd /Users/dysania/program/tools/agent-tools/water-reminder
./uninstall-launch-agent.sh
```

## 可调参数

```bash
swift water_reminder.swift --interval 20
swift water_reminder.swift --message '太辛苦了！快去喝水！'
swift water_reminder.swift --once --display-seconds 5
swift water_reminder.swift --once --exit-seconds 2
swift water_reminder.swift --once --confirm-text '喝完了'
```

`--display-seconds` 控制飞到中间的时长，默认 4 秒。提醒停在中间后不会自动消失，必须点击确认按钮。

如果提醒影响操作，直接运行 `./uninstall-launch-agent.sh` 停止系统定时服务。修复或预览时不要运行安装脚本。

## 验证

```bash
bash tests/test_water_reminder_cli.sh
swiftc water_reminder.swift -o /tmp/water-reminder-check
swift water_reminder.swift --once --display-seconds 1 --auto-confirm-seconds 1 --exit-seconds 1
```
