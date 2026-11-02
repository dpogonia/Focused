[Русский](README.md) | **English**

# Focused

The first test version of YULO, the main tracker. On iPhone and iPad it keeps life spheres, goals, tasks, habits, and notes. Data stays on the device.

On the first launch the app adds sample items so the screens are not empty.

## Features

**Vision**

- life spheres: title, color, icon, and satisfaction
- how goals, tasks, and habits affect a sphere
- charts: radar, rings, and bars
- an optional short sphere review from an external model. Without your own key this part stays quiet, and the other tabs still work

**Goals**

- due date, reward, status, and archive
- subtasks and counters
- a photo or an icon, color, and tags
- a link to a sphere, and a flag for goals that appear on the Vision grid

**Tasks**

- due date, repeat, and status
- subtasks
- estimated and actual time
- a link to a goal and a sphere

**Habits**

- a schedule and how many times to check a habit in a day
- done, missed, and skipped
- streaks and archive
- color, icon, tags, and a link to a sphere

**Notes**

- note album, list, counter, and streak
- mood, skill, budget, time, health, and calendar
- tags and archive

**Shared**

- one calendar across all tabs
- a dashboard for a week, month, quarter, and year
- a JSON backup of spheres, goals, tasks, habits, and notes

## Stack

| | |
| --- | --- |
| UI | SwiftUI, Charts |
| Storage | SwiftData |
| Navigation | tab coordinator |
| Vision analytics | HTTP Chat Completions, OpenRouter by default |

## Requirements

- Xcode 26
- iPhone or iPad on iOS 17.6 or later
- your own OpenRouter key, only for sphere reviews. The rest of the app does not need it

## Run

```bash
git clone https://github.com/dpogonia/Focused.git
cd Focused
open Focused.xcodeproj
```

Pick an iPhone simulator and run the **Focused** scheme.

### Vision key

The key is not in the repository. Set it in either place:

- the `VISION_ANALYTICS_API_KEY` environment variable on the scheme: Product → Scheme → Edit Scheme → Run → Arguments → Environment
- or the target setting `INFOPLIST_KEY_VisionAnalyticsAPIKey`

By default the request goes to `https://openrouter.ai/api/v1/chat/completions` with the model `deepseek/deepseek-chat`. The URL and model come from the same Info.plist settings: `VisionAnalyticsEndpointURL` and `VisionAnalyticsModelName`.

## Structure

```
Focused/
├── App/         entry point
├── Core/        dependencies and tabs
├── Features/    Vision, Goals, Tasks, Habits, Memo
├── Services/    samples, backup, and the model request
└── Shared/      shared screens and models
FocusedTests/
```

## Author

[Dmitrii Pogonia](https://github.com/dpogonia)
