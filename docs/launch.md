# Launch Notes

CoolBoard is positioned as an open source macOS utility for Apple Silicon developers who run sustained local workloads, including agentic coding, builds, tests, indexing, and AI tooling.

## GitHub Positioning

Short description:

```text
Minimal macOS cooling dashboard for Apple Silicon Macs.
```

Suggested topics:

```text
macos apple-silicon swift swiftui fan-control thermal-monitoring smc developer-tools agentic-coding open-source
```

## Show HN

Hacker News `Show HN` submissions are posted through the normal Hacker News submit form. The title should start with `Show HN:` and link directly to the project.

Submit URL:

```text
https://news.ycombinator.com/submit
```

Suggested title:

```text
Show HN: CoolBoard - open-source Apple Silicon thermal monitor and fan control
```

Suggested URL:

```text
https://github.com/Rafinelio/CoolBoard
```

Suggested first comment:

```text
I built CoolBoard as a small open-source macOS utility for developers running long local workloads on Apple Silicon Macs. It shows AppleSMC/IORegistry thermal data, detected fan count, current RPM, and guarded manual fan presets with Auto restore on sleep/wake and app exit. Sleep/wake clears manual targets instead of resuming them automatically.

The first release is intentionally conservative: Apple Silicon only, MIT licensed, outside the Mac App Store, and clearly marked as using private AppleSMC mechanisms for fan control. Fanless MacBook Air models run monitoring only.

I am especially looking for compatibility reports across M-series MacBook Pro, Mac mini, Mac Studio, and MacBook Air models.
```

Practical notes:

- Do not ask people to upvote. Hacker News treats vote solicitation badly.
- Submit after the GitHub release exists and the README screenshot renders.
- Stay in the comments for the first few hours and answer technical questions directly.
- If the submission does not get attention, avoid reposting the same link immediately.

Reference: https://news.ycombinator.com/showhn.html
