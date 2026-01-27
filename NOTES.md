Load the n8n workflow from the n8n folder.

```bash
docker ps
docker exec -it -u node 3a01fdcfd5a3 n8n import:workflow --separate --input=/home/node/workflows/
```
