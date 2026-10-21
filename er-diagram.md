# Current schema

NN means NOT NULL; primary keys are implicitly required. `user_first_seen` is a derived view over loaded stories/comments and is not a stored entity. The PNG is the historical Project 1 diagram.

```mermaid
erDiagram
    USERS o|--o{ STORIES : submits
    USERS o|--o{ COMMENTS : writes
    DOMAINS o|--o{ LINKS : hosts
    LINKS o|--o{ STORIES : references
    STORIES ||--o{ COMMENTS : "has comments on"
    STORIES ||--o{ STORY_TAGS : "tagged with"
    COMMENTS o|--o{ COMMENTS : "replies to"
    STORIES ||--o| POLLS : "is a"
    POLLS ||--}| POLL_OPTIONS : has

    USERS {
        string username PK
    }
    DOMAINS {
        int domain_id PK
        string domain_name UK "NN"
    }
    LINKS {
        string url PK
        int domain_id FK
    }
    STORIES {
        bigint story_id PK
        string author FK
        string title "NN"
        string url FK
        string story_text
        int points "NN"
        int num_comments "NN"
        boolean is_ask_hn "NN"
        boolean is_show_hn "NN"
        timestamptz created_at "NN"
        timestamptz updated_at "NN"
    }
    STORY_TAGS {
        bigint story_id PK "FK"
        string tag PK
    }
    COMMENTS {
        bigint comment_id PK
        bigint story_id FK "NN"
        bigint parent_comment_id FK
        string author FK
        string comment_text
        timestamptz created_at "NN"
    }
    POLLS {
        bigint poll_id PK "FK"
    }
    POLL_OPTIONS {
        bigint poll_option_id PK
        bigint poll_id FK "NN"
        string option_text
        int points "NN"
    }
```
