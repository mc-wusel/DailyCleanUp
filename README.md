# DailyCleanUp

# Process 
```mermaid
flowchart TD
    A[Start] --> B{read config.json} -->|Addition Folders available |C[Add] -->E
    B--> | nothing available| E[Delete Folders]
    E--> F[Show Folder Infos] -->G[End]
```
