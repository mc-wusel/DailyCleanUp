# DailyCleanUp

# Process 
By default, the following directories are deleted
- SystemDrive\Windows\Temp
- SystemDrive\Windows\Prefetch
- SystemDrive\Windows\Logs\CBS
- SystemDrive\Windows\SoftwareDistribution\Download\

```mermaid
flowchart TD
    A[Start] --> B{read config.json} -->|Addition Folders available |C[Add] -->E
    B--> | nothing available| E[Delete Folders]
    E--> F[Show Folder Infos] -->G[End]
```
