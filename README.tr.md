# PostgreSQL Performance Benchmark

[Deutsch](README.md) · [English](README.en.md) · [Türkçe](README.tr.md)

**100.000 ve 1.000.000 sentetik olay kaydıyla** hazırlanmış, yeniden çalıştırılabilir bir SQL performans projesi. Veri kalitesini, CSV aktarımını, beş SQL iş yükünü ve sorgu hızı ile depolama/yazma maliyeti arasındaki dengeyi inceler.

**Python · PostgreSQL · SQL · Docker Compose · B-tree · Query plans**

## Orijinal yerel deneyin sonuçları

| Sorgu | Yalnızca primary key | İki ek indeksle |
| --- | ---: | ---: |
| Q1 | 0.061 ms | 0.062 ms |
| Q2 | 260.336 ms | 262.466 ms |
| Q3 | 38.874 ms | 37.244 ms |
| Q4: Tarih aralığı | 17.839 ms | 2.210 ms |
| Q5: Müşteri geçmişi | 19.353 ms | 0.069 ms |

Q4 yaklaşık **8,07 kat**, Q5 ise **280,48 kat** hızlandı. Toplam depolama yaklaşık **101 MB’den 156 MB’ye** yükseldi. Ayrı bir 100 bin satırlık aktarım deneyinde iki ek indeksle medyan süre **192,820 ms’den 473,743 ms’ye** çıktı (2,457 kat). Q1–Q3 bu indekslerden belirgin bir fayda görmedi.

## Teknik kapsam

- Primary key, `NOT NULL` ve `CHECK` kurallarıyla ilişkisel şema tasarımı.
- `\copy` ile toplu CSV aktarımı; satır sayısı, ID ve veri kalitesi doğrulaması.
- Tek kayıt arama, aylık gelir, en yüksek gelirli ürünler, tarih aralığı ve müşteri geçmişi sorguları.
- `event_ts` ve `(customer_id, event_ts DESC, event_id DESC)` üzerinde B-tree indeksleri.
- `EXPLAIN (ANALYZE, BUFFERS)` ile sorgu planı analizi ve korunmuş ham ölçümler.

## Docker ile çalıştırma

Gereksinimler: Docker, Compose v2 (`--wait` desteği) ve bilgisayarda Python 3. Komut verileri üretir, PostgreSQL’i başlatır, 1 milyon kayıt üzerinde indeks öncesi/sonrası sorguları ölçer, ayrı 100 bin kayıtlık aktarım karşılaştırmasını çalıştırır ve yeni medyanları hesaplar. İlk image indirmesi için internet gerekir. Bilgisayara veritabanı portu açılmaz.

```bash
cd postgresql-performance-benchmark
bash scripts/reproduce.sh
```

Ana tablo boş olmalı ve yalnızca primary key indeksini içermelidir. Bağımsız bir tekrar için yeni bir Compose proje adı kullan:

```bash
COMPOSE_PROJECT_NAME=pg_benchmark_run2 bash scripts/reproduce.sh
```

Veritabanı volume’unu koruyarak konteynerleri durdur:

```bash
docker compose down
```

`results/reproduction/<run-id>/summary.csv`

## Docker olmadan çalıştırma

Python 3, PostgreSQL ve `psql` kur. Ayrıntılı yerel adımlar [orijinal laboratuvar raporunda](docs/ACADEMIC_REPORT.md) bulunur. Aktarım scripti `PGDATABASE`, `CSV` ve `OUT` değişkenlerini destekler; yerel bağlantı için standart PostgreSQL ortam değişkenleri kullanılabilir.

```bash
PGDATABASE=bigdata_lab CSV=data/events.csv OUT=results/reproduction/import_manual bash scripts/meeting4_import_benchmark.sh
```

## Dosyalar

| Path | Content |
| --- | --- |
| `generate_events.py` | Course-supplied deterministic generator |
| `sql/` | Schema, validation, workloads, indexes |
| `scripts/reproduce.sh` | Docker reproduction |
| `scripts/summarize.py` | New query median summary |
| `scripts/meeting4_import_benchmark.sh` | Import A/B benchmark |
| `results/` | Original raw measurements and plans |
| `logs/` | Original laboratory records |
| `report/` | Original academic PDF |
| `docs/ACADEMIC_REPORT.md` | Original detailed README |
| `.github/workflows/ci.yml` | Reproduction smoke test |

## Yöntem ve sınırlar

Orijinal ortam: Apple M4 Pro, 24 GB RAM, macOS 26.1, PostgreSQL 14.18 ve Python 3.9.6. Her okuma sorgusunda bir ısınma ve üç ölçüm yapılır; medyana ısınma dahil edilmez. Süreler `psql \timing` ile ölçülür; EXPLAIN süreleri ayrı değerlendirilir. Aktarım karşılaştırmasında koşul başına beş ölçüm ve dönüşümlü sıra kullanılmıştır. Önbellek ve arka plan yükü tamamen kontrol edilmemiştir. Bunlar yerel gözlemlerdir; üretim ortamı garantisi değildir. Bir milyon kayıt, dağıtık büyük veri mimarisi kurulduğu anlamına gelmez.

Orijinal 100 bin/1 milyon Q5 karşılaştırmasında eşleşen satır sayıları farklıdır; küçük veri setinde hiç eşleşme yoktur. Bu karşılaştırmadan genel bir ölçeklenme sonucu çıkarılmaz. Ayrıntılar ve ayrı takip deneyi laboratuvar raporundadır.

## Kaynak ve yayınlama

Cenker Sule’nin üniversite çalışmasından portföy sunumuna uyarlanmıştır. Olay üreticisi ders tarafından sağlanmıştır; bu kodun yazarlığı sahiplenilmez. Generator’ı herkese açık paylaşmadan önce yeniden dağıtım iznini netleştir. [NOTICE](NOTICE.md) dosyasına bak.

## Doğrulama

Orijinal medyanlar yeniden hesaplandı. Python/Bash kontrolleri, küçük veri üretimi ve süre özetleme denemeleri yapıldı. Bu ortamda Docker/PostgreSQL bulunmadığından yeni konteyner akışı ve GitHub Actions henüz çalıştırılmadı. [Doğrulama notu](docs/VALIDATION.md).
