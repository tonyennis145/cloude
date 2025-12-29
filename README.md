# Cloude

A Slack-to-Claude Code bridge that lets you interact with [Claude Code CLI](https://github.com/anthropics/claude-code) through Slack messages.

## Features

- **Threaded Conversations**: Start new threads by messaging the bot directly, or continue existing conversations by replying in a thread. Each Slack thread maintains its own Claude session context.
- **Live Status Updates**: See what Claude is doing in real-time with status messages like "Using Read...", "Using Bash...", or "Generating response..." that update as Claude works.
- **Persistent Sessions**: Conversations are resumed using Claude's `--resume` flag, so context is maintained across messages within a thread.
- **Dangerously Skip Permissions**: Runs Claude with `--dangerously-skip-permissions` for uninterrupted execution while preserving thread context.
- **Message Deduplication**: Handles Slack's retry behavior gracefully to prevent duplicate processing.
- **Markdown Conversion**: Automatically converts Claude's markdown output to Slack-compatible formatting.

## How It Works

1. Send a message to the Cloude bot in Slack (DM or mention)
2. The bot adds an "eyes" reaction to show it's processing
3. A "Thinking..." message appears and updates with Claude's current activity
4. When complete, the message updates with the full response and a checkmark reaction appears

## Setup

### Prerequisites

- Ruby 3.x
- PostgreSQL
- A Slack app with bot token and signing secret
- Claude Code CLI installed

### Environment Variables

```bash
SLACK_BOT_TOKEN=xoxb-...        # Slack bot OAuth token
SLACK_SIGNING_SECRET=...        # Slack app signing secret
SLACK_DEFAULT_CHANNEL=@user     # Default channel for notifications
API_KEY=...                     # API key for protected endpoints
DATABASE_URL=...                # PostgreSQL connection string
```

### Installation

```bash
git clone https://github.com/your-username/cloude.git
cd cloude
bundle install
bundle exec rake db:migrate
```

### Running

```bash
# Development
bundle exec ruby singlefile.rb

# Production (with Passenger)
passenger start --daemonize -p 3333
```

## API Endpoints

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `POST /slack/events` | Slack signature | Webhook receiver for Slack events |
| `POST /notify` | API key | Send a message to Slack |
| `GET /threads` | API key | List conversation threads |
| `POST /threads` | API key | Create a new thread |
| `GET /threads/:id` | API key | Get thread with messages |

## Slack App Configuration

Your Slack app needs:

- **Event Subscriptions** enabled, pointing to `https://your-domain.com/slack/events`
- **Subscribe to bot events**: `message.im`, `app_mention`
- **OAuth Scopes**: `chat:write`, `reactions:write`, `reactions:read`

## License

MIT
