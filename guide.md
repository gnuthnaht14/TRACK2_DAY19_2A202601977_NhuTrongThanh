# Guide hoàn thiện Day 19 — Vector Store + Feature Store

Tài liệu này giúp bạn hiểu dự án đang giải quyết bài toán gì, từng thành phần
liên kết với nhau như thế nào, cần viết phần code nào và phải tạo bằng chứng gì
để hoàn thành bài lab.

> **Phạm vi của guide:** chỉ sử dụng **Lite path** trên Windows. Toàn bộ hướng
> dẫn bên dưới dùng FastEmbed, Qdrant in-memory, Feast SQLite/Parquet và không
> yêu cầu Docker, Redis, PostgreSQL, GPU hoặc OpenAI API key.

## 1. Mục tiêu của dự án

Dự án xây dựng một hệ thống tìm kiếm tài liệu tiếng Việt có ba chế độ:

1. **Keyword search** dùng BM25: tốt khi query chứa đúng từ xuất hiện trong tài
   liệu.
2. **Semantic search** dùng embedding và Qdrant: tốt khi query diễn đạt lại ý
   nghĩa bằng từ khác.
3. **Hybrid search** dùng Reciprocal Rank Fusion (RRF): hợp nhất thứ hạng của
   BM25 và semantic search.

Sau khi xây dựng search engine, dự án đưa nó ra ngoài qua FastAPI, đo chất lượng
bằng Precision@10, đo độ trễ bằng P50/P95/P99, rồi bổ sung Feast để quản lý
feature offline/online theo đúng thời điểm.

Phần core gồm NB1–NB4 và có tổng 100 điểm. NB5–NB8 là phần nâng cao 50 điểm.
Bonus AI Memory là phần tùy chọn riêng.

## 2. Kiến trúc tổng thể

```text
data/corpus_vn.jsonl (1.000 tài liệu)
            |
            +-------------------------+
            |                         |
            v                         v
       BM25 index              Embedding model
            |                         |
            |                         v
            |                  Qdrant vector index
            |                         |
            +------------+------------+
                         |
                         v
                  RRF hybrid ranking
                         |
                         v
               FastAPI GET /search
                         |
             quality + latency benchmark

Synthetic user/item/query events
            |
            v
    Feast offline store (Parquet)
            |
       materialization
            |
            v
     Feast online store (SQLite)
            |
            +--> online lookup
            +--> point-in-time historical join
```

Trong guide này, Qdrant luôn chạy trong bộ nhớ và Feast luôn dùng
SQLite/Parquet. Không cần khởi động service bên ngoài.

## 3. Các khái niệm cần hiểu

### BM25

BM25 xếp hạng dựa trên từ xuất hiện trong query và tài liệu. Nó mạnh với query
`exact`, nhẹ và nhanh, nhưng yếu khi người dùng diễn đạt cùng một ý bằng từ khác.

### Embedding và vector search

Embedding biến văn bản thành vector số. Qdrant tìm các vector gần query nhất
theo cosine similarity. Cách này xử lý paraphrase tốt hơn, nhưng chất lượng phụ
thuộc mạnh vào model.

Model mặc định Lite là `BAAI/bge-small-en-v1.5`, dimension 384. Model này nhẹ
nhưng thiên về tiếng Anh. Khi đổi sang model 1024 hoặc 1536 chiều, bạn bắt buộc
phải tạo lại collection và index lại corpus.

### Reciprocal Rank Fusion

Không nên cộng trực tiếp BM25 score với cosine score vì hai hệ điểm không cùng
thang đo. RRF chỉ dùng thứ hạng:

```text
RRF_score(document) = tổng của 1 / (k + rank)
```

Trong bài này `k = 60` và `rank` bắt đầu từ 1. Document xuất hiện ở cả BM25 và
semantic list nhận điểm từ cả hai nguồn.

### Precision@10

Precision@10 trả lời câu hỏi: trong 10 kết quả đầu, có bao nhiêu kết quả đúng?

```text
Precision@10 = số kết quả liên quan trong top 10 / 10
```

Golden set chứa query, loại query và danh sách/nhãn liên quan để đánh giá ba
search mode một cách nhất quán.

### P50, P95 và P99

- P50 là độ trễ điển hình.
- P95 là ngưỡng mà 95% request nhanh hơn hoặc bằng.
- P99 đại diện cho tail latency, thường là chỉ số production quan trọng nhất.

Phải warm-up trước khi đo để không tính thời gian tải model và dựng index vào
request thông thường.

### Feature Store và point-in-time join

Feature Store giữ định nghĩa và dữ liệu feature nhất quán giữa training và
serving. Online lookup cần nhanh; historical join cần đúng theo thời điểm.

Point-in-time join chỉ cho một training event nhìn thấy feature đã tồn tại ở
thời điểm event. Nếu lấy giá trị mới nhất từ tương lai, mô hình bị data leakage.

## 4. Cấu trúc repo cần biết

| Đường dẫn | Vai trò |
|---|---|
| `notebooks/01...08_*.py` | Nguồn Jupytext, dễ review và chứa bài tập/TODO |
| `notebooks/01...08_*.ipynb` | Notebook để chạy, giữ output và nộp bài |
| `app/search.py` | Searcher BM25, semantic và hybrid |
| `app/embeddings.py` | Chọn embedding backend và dimension |
| `app/main.py` | FastAPI `/search`, `/healthz`, `/docs` |
| `app/feast_repo/` | Feast configuration và ba feature views |
| `app/filters.py` | Filtered search cho NB5 |
| `app/agent.py` | Planner, retrieval tool và context cho NB6 |
| `app/cache.py` | Semantic cache cho NB7 |
| `app/features.py` | Feature engineering và leakage cho NB8 |
| `scripts/seed_corpus.py` | Sinh corpus và golden set deterministic |
| `scripts/benchmark.py` | Benchmark quality và latency |
| `tests/` | 41 automated tests hiện có |
| `submission/` | Reflection và screenshots để nộp |

Không nhầm hai loại notebook:

- Sửa logic bài tập trong file `.py` hoặc trong `.ipynb` có Jupytext pairing.
- File `.ipynb` được setup sinh tự động và phải được giữ lại để nộp output.
- `_setup.py` là helper, không phải notebook cần chạy.

## 5. Chuẩn bị môi trường trên Windows

Môi trường Lite đủ cho mọi tiêu chí core. Không chạy `make setup-docker`,
`make docker-up` hoặc thay `QDRANT_MODE` thành `server`.

Cấu hình `.env` cần giữ như sau:

```dotenv
QDRANT_MODE=memory
EMBEDDING_BACKEND=fastembed
FEAST_ONLINE_STORE=sqlite
FEAST_OFFLINE_STORE=file
```

```powershell
make setup-lite
make verify-lite
make test
```

Kết quả mong đợi:

```text
All checks passed — lite path is ready.
41 passed
```

Nếu không dùng Make:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-lite.ps1
```

Các lệnh Make gọi trực tiếp executable trong `.venv`, vì vậy không bắt buộc
activate virtual environment. Nếu muốn activate để chạy lệnh thủ công:

```powershell
.\.venv\Scripts\Activate.ps1
```

## 6. Quy trình hoàn thiện core

Không làm tất cả notebook cùng lúc. Hoàn thành theo thứ tự NB1 → NB2 → NB3 →
NB4 vì mỗi bước dùng kết quả và khái niệm từ bước trước.

### NB1 — Embedding và Qdrant index

File nguồn: `notebooks/01_embeddings_index.py`.

Mục tiêu là đưa đủ 1.000 tài liệu vào collection `lab19`, sau đó chạy semantic
search.

Các bước code:

1. Đọc `data/corpus_vn.jsonl` thành danh sách document.
2. Khởi tạo embedding model và Qdrant client.
3. Tạo collection với cosine distance và đúng vector dimension.
4. Chia corpus thành batch, ví dụ 64 document mỗi batch.
5. Ghép `title + text` trước khi embed.
6. Tạo `PointStruct` gồm ID, vector và payload.
7. Upsert batch vào Qdrant.
8. Kiểm tra count đúng 1.000.
9. Embed query rồi gọi `query_points()` để lấy top 5.
10. Chạy paraphrase query không chứa literal `cloud` và kiểm tra topic của top 5.

Khung thuật toán:

```python
for start in range(0, len(docs), batch_size):
    batch = docs[start:start + batch_size]
    texts = [doc["title"] + " " + doc["text"] for doc in batch]
    vectors = list(embedder.embed(texts))
    points = [...]  # id + vector + payload
    client.upsert(collection_name="lab19", points=points)
```

Không hard-code dimension nếu backend đã cung cấp `embedder.dim`. Payload nên
giữ ít nhất `doc_id`, `title`, `text` và `topic` để đánh giá được kết quả.

Điều kiện hoàn thành:

- `client.count("lab19").count == 1000`.
- Top 5 keyword query được hiển thị.
- Top 5 paraphrase chủ yếu thuộc topic `cloud`.

Ảnh cần chụp: count 1.000 và bảng top 5 paraphrase.

### NB2 — BM25, semantic và hybrid RRF

File nguồn: `notebooks/02_hybrid_search_rrf.py`.

Các bước code:

1. Dựng BM25 index từ cùng corpus.
2. Viết hàm keyword search trả danh sách có thứ tự.
3. Dùng vector index cho semantic search.
4. Lấy candidate list sâu hơn top 10, ví dụ 50 kết quả từ mỗi retriever.
5. Implement RRF với rank 1-based.
6. Sort theo RRF score giảm dần và lấy top 10.
7. Chạy toàn bộ 50 golden queries cho ba mode.
8. Tính Precision@10 trung bình.
9. Group theo `exact`, `paraphrase`, `mixed`.

Khung RRF:

```python
scores = {}
metadata = {}

for hits in (keyword_hits, semantic_hits):
    for rank, hit in enumerate(hits, start=1):
        scores[hit.doc_id] = scores.get(hit.doc_id, 0.0) + 1 / (60 + rank)
        metadata.setdefault(hit.doc_id, hit)
```

Các lỗi thường gặp:

- Dùng `enumerate(hits)` làm rank bắt đầu từ 0.
- Cộng raw BM25 score với cosine score.
- Một nguồn dùng integer ID, nguồn kia dùng string `doc_id`.
- Chỉ lấy top 10 từ mỗi nguồn khiến RRF có quá ít candidate.

Điều kiện hoàn thành:

- Hybrid trung bình cao hơn keyword và semantic.
- Hybrid thắng trên slice `mixed`.
- Semantic thường thắng `paraphrase`.
- BM25 thường thắng `exact`, hoặc kết quả gần với pattern này.

Ảnh cần chụp: bảng trung bình ba mode và bảng chia theo query type.

### NB3 — FastAPI và latency benchmark

File nguồn: `notebooks/03_search_api_benchmark.py`.

API đã được tổ chức tại `app/main.py`. Searcher phải được dựng một lần ở startup
và dùng lại, vì việc tải model/index lại trong mỗi request sẽ phá latency.

Endpoint chính:

```http
GET /search?q=<query>&mode=keyword|semantic|hybrid&top_k=10
```

Response cần chứa:

- `query`;
- `mode`;
- `top_k`;
- `latency_ms` server-side;
- danh sách `hits`.

Quy trình:

1. Khởi động API bằng `make api` trong terminal riêng.
2. Chờ `/healthz` báo ready.
3. Gửi một request và kiểm tra response shape.
4. Warm-up ít nhất 10 request.
5. Gửi 100 request cho mỗi mode.
6. Thu `latency_ms` trong response, không dùng tổng network time làm số rubric.
7. Tính P50/P95/P99 bằng cùng một cách cho cả ba mode.
8. In bảng kết quả và assertion cho hybrid P99.

Ví dụ kiểm tra thủ công:

```powershell
Invoke-RestMethod "http://localhost:8000/search?q=cloud%20computing&mode=hybrid&top_k=10"
```

Điều kiện hoàn thành:

- Response hợp lệ và có `latency_ms`.
- Có bảng P50/P95/P99 cho đủ ba mode.
- Hybrid P99 server-side dưới 50 ms sau warm-up.

Nếu P99 cao, kiểm tra Searcher có bị dựng lại hay không, model có bị tải lại mỗi
request hay không, và benchmark có vô tình đo cold start hay network time không.

Ảnh cần chụp: sample API response và bảng latency.

### NB4 — Feast Feature Store

File nguồn: `notebooks/04_feast_feature_store.py`.

Ba feature views là:

1. `user_profile_features`: reading speed, language và topic affinity.
2. `item_popularity_features`: clicks, CTR và dwell time của document.
3. `query_velocity_features`: tốc độ và độ đa dạng query gần đây của user.

Quy trình:

1. Sinh ba file Parquet offline với đúng entity key và `event_timestamp`.
2. Chạy `feast apply` để đăng ký entity, source và feature view.
3. Liệt kê feature views và xác nhận đủ ba view.
4. Chạy materialization để đẩy feature mới vào SQLite online store.
5. Gọi `get_online_features()` cho `user_id=u_001` và một `doc_id` hợp lệ.
6. Warm-up rồi benchmark 100 online lookup.
7. In P50/P95/P99; mục tiêu P99 dưới 10 ms.
8. Tạo entity DataFrame có ba event timestamp.
9. Gọi `get_historical_features()` và kiểm tra point-in-time join trả ba dòng.

Khi chạy Feast thủ công trên PowerShell:

```powershell
Push-Location app\feast_repo
..\..\.venv\Scripts\feast.exe apply
..\..\.venv\Scripts\feast.exe feature-views list
Pop-Location
```

Điều kiện hoàn thành:

- `feast apply` thành công và có đủ ba views.
- Materialization log cho thấy dữ liệu được ghi vào online store.
- Online lookup trả dictionary hợp lệ.
- Có benchmark 100 lookup.
- Historical join trả đúng ba dòng và không nhìn thấy tương lai.

Ảnh cần chụp: apply/materialize log, online lookup, latency và PIT DataFrame.

## 7. Khối nâng cao NB5–NB8

Chỉ bắt đầu phần này sau khi NB1–NB4 chạy ổn định.

### NB5 — Filtered search

So sánh ba chiến lược:

- Post-filter: ANN trước, lọc sau; dễ mất recall khi filter chặt.
- Pre-filter/exact: lọc candidate trước rồi tìm chính xác.
- Filtered ANN: đưa filter vào Qdrant query.

Cần tạo bảng recall theo độ chọn lọc và over-fetch ladder. Kết quả mong đợi là
post-filter giảm mạnh ở filter khoảng 4%, trong khi filtered ANN giữ recall 1.00.

### NB6 — Agentic retrieval

Biến retrieval thành tool, để planner tách câu hỏi nhiều ý thành nhiều lần gọi.
So sánh ba chiến lược ở cùng ngân sách 16 documents; nếu một phương pháp được
lấy nhiều document hơn thì so sánh không còn công bằng.

Cần báo cáo recall, balance, trace reflection và output `build_context()` có cả
feature lẫn `doc_ids`. Phải giải thích tại sao filter đoán sai có thể làm agentic
`+filter` kém hơn `no filter`.

### NB7 — Semantic cache

Triển khai/đánh giá:

- similarity threshold;
- TTL;
- tenant namespace;
- hit rate và wrong-answer rate.

Không chỉ tối đa hóa cache hit. Threshold quá thấp có thể trả câu trả lời của một
query gần giống nhưng khác ý. Demo bắt buộc phải cho thấy leak khi
`namespaced=False` và MISS khi `namespaced=True`.

### NB8 — Feature engineering

Đánh giá feature theo tính nhân quả, không chỉ theo AUC. Cần:

- chứng minh naive target encoding leak mạnh trên `session_id`;
- so sánh in-fold encoding;
- so sánh latest join với PIT join;
- báo cáo phần trăm dòng leak và AUC gap;
- chạy on-demand feature view để cùng user nhưng hai `amount` tạo hai
  `amount_vs_avg` khác nhau.

## 8. Workflow coding nên dùng

Lặp lại vòng sau cho từng notebook:

1. Đọc toàn bộ notebook và xác định output rubric.
2. Chạy notebook đến cell TODO để thấy lỗi/baseline.
3. Viết một phần nhỏ nhất có thể kiểm tra được.
4. Chạy test liên quan.
5. Chạy lại notebook từ kernel sạch.
6. Kiểm tra assertion và tính hợp lý của bảng, không chỉ kiểm tra “không lỗi”.
7. Viết diễn giải bằng lời của chính bạn.
8. Chụp bằng chứng ngay khi kết quả đúng.

Các lệnh kiểm tra thường xuyên:

```powershell
make verify-lite
make test
make benchmark
```

Trước khi nộp, chạy toàn bộ notebook headless:

```powershell
make notebooks
```

Lệnh này mô phỏng gần nhất cách grader thực thi. Nếu notebook chỉ chạy được do
state còn sót trong kernel, headless execution sẽ phát hiện.

## 9. Checklist debug

### NB1 không đủ 1.000 vectors

- Chạy `make seed`.
- Kiểm tra loop có bỏ sót batch cuối không.
- Kiểm tra upsert có dùng ID trùng nhau không.
- Nếu đổi model, recreate collection với dimension mới.

### Hybrid không thắng

- Kiểm tra RRF rank bắt đầu từ 1.
- Kiểm tra candidate depth.
- Kiểm tra hai nguồn dùng cùng `doc_id`.
- Xem riêng ba query slice thay vì chỉ nhìn average.
- Nhớ rằng fastembed mặc định yếu hơn với paraphrase tiếng Việt.

### API P99 vượt 50 ms

- Warm-up trước khi đo.
- Không dựng lại Searcher trên từng request.
- Không tính thời gian startup/network vào `latency_ms` server-side.
- Chạy benchmark lần hai sau khi model cache đã nóng.

### Feast apply lỗi

- Kiểm tra các file Parquet đã được sinh.
- Kiểm tra `event_timestamp` có timezone/type hợp lệ.
- Khi registry cũ không tương thích, có thể chạy `make clean-lite` rồi setup lại;
  lưu ý target này xóa venv, data sinh tự động, registry và notebook `.ipynb`.
- Không chạy `clean-lite` nếu chưa lưu output notebook cần giữ.

## 10. Hoàn thiện deliverable

Core bắt buộc phải có bốn notebook đã chạy và các ảnh sau:

| Notebook | Bằng chứng tối thiểu |
|---|---|
| NB1 | 1.000 vectors và top 5 paraphrase đúng topic |
| NB2 | Bảng Precision@10 trung bình và theo query type |
| NB3 | API response và bảng P50/P95/P99 |
| NB4 | Feast apply/materialize, online lookup và PIT join |

Lưu ảnh trong `submission/screenshots/`. Điền `submission/REFLECTION.md` không
quá 200 chữ, tập trung trả lời:

- Mode nào thắng exact query và vì sao?
- Mode nào thắng paraphrase và vì sao?
- Tại sao hybrid phù hợp mixed query?
- Khi nào chi phí/latency khiến bạn không chọn hybrid?

Kiểm tra cuối:

```powershell
make verify-lite
make test
make benchmark
make notebooks
git status
```

Sau đó commit cả source cần thiết, notebook `.ipynb` có output,
`submission/screenshots/` và reflection. Push lên GitHub public, nộp URL vào LMS
và giữ repository public cho tới khi có điểm.

## 11. Thứ tự ưu tiên nếu thời gian có hạn

1. NB1: index đủ 1.000 vector và chứng minh semantic retrieval.
2. NB2: RRF đúng và có Precision@10.
3. NB3: API cùng latency table.
4. NB4: Feast online/offline/PIT.
5. Chạy lại core từ môi trường sạch và hoàn thiện evidence.
6. NB5–NB8.
7. Bonus AI Memory.

Mục tiêu đầu tiên nên là khóa chắc 100 điểm core. Không nên bắt đầu bonus khi
NB1–NB4 chưa chạy headless thành công và chưa có đủ ảnh bằng chứng.
