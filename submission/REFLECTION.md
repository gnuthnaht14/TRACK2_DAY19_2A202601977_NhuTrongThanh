# Reflection — Lab 19

**Tên:** _Nhữ Trọng Thành_
**Cohort:** _A20-K3_
**Path đã chạy:** Lite

---

## Câu hỏi (≤ 200 chữ)

> Trên golden set 50 queries, mode nào thắng ở loại query nào (`exact` /
> `paraphrase` / `mixed`), và tại sao? Khi nào bạn **không** dùng hybrid
> (i.e. khi nào pure BM25 hoặc pure vector là lựa chọn đúng)?

Trên golden set 50 queries, Hybrid RRF thắng trung bình với Precision@10
78,6%, cao hơn BM25 (77,8%) và semantic search (73,2%). Với query `exact`,
BM25 và hybrid cùng đạt 96,7% vì các thuật ngữ kỹ thuật xuất hiện trực tiếp
trong corpus. Với `mixed`, hybrid đạt 100%, cao hơn BM25 97,0% và semantic
98,5%, vì RRF giữ được cả tín hiệu từ khóa lẫn ý nghĩa. Kết quả đáng chú ý là
ở `paraphrase`, semantic chỉ đạt 24,0%, thấp hơn BM25 33,3%; nguyên nhân là
Lite path dùng `bge-small-en-v1.5`, model thiên về tiếng Anh nên chưa phù hợp
tối ưu cho diễn đạt tiếng Việt.

Tôi không dùng hybrid khi truy vấn chỉ cần match thuật ngữ chính xác, cần độ
trễ/chi phí thấp nhất, hoặc corpus quá nhỏ và BM25 đã đủ tốt. Pure vector phù
hợp hơn khi dùng embedding đa ngôn ngữ tốt và query chủ yếu là paraphrase,
không phụ thuộc keyword.

---

## Điều ngạc nhiên nhất khi làm lab này

Điều bất ngờ nhất là lựa chọn embedding model ảnh hưởng rõ hơn cả việc chỉ
thêm RRF: model Lite tiếng Anh làm semantic search yếu ở paraphrase tiếng Việt.

---

## Bonus challenge

- [ ] Đã làm bonus (xem `bonus/`)
- [ ] Pair work với: _<tên đồng đội nếu có>_
