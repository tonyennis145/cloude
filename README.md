# Cloude App (Slack Hub)

The Cloude app is a Sinatra app that:
- Receives messages from Slack and routes them to Claude CLI
- Sends responses back to Slack (in threads)
- Stores conversations in Postgres (`play_development` database)
- Can schedule tasks and send notifications

## API Endpoints

All endpoints except `/slack/events` require `X-API-Key` header.

| Endpoint | Purpose |
|----------|---------|
| `POST /notify` | Send a Slack message |
| `GET/POST /tasks` | List/create scheduled tasks |
| `GET/POST /threads` | List/create conversation threads |
| `POST /slack/events` | Slack webhook receiver |

## Task Runner

```bash
cd /sync/Universe/Apps/code/cloude && bundle exec rake tasks:run
```

Set up as cron job to run every minute for scheduled task execution.
