# Запуск пайплайна в Docker

Контейнер считает тяжёлую часть анализа: загрузка ридов из SRA → очистка
(cutadapt, DADA2) → ASV → таксономия (DECIPHER/SILVA) → функциональное
предсказание (PICRUSt2). На выходе — два архива: `results.zip` и `data_temp.zip`.

Ничего, кроме Docker, ставить не нужно: Snakemake, R, conda-окружения уже в образе.

## Требования

| | |
|---|---|
| ОС | Linux x86-64 (на macOS/Windows через Docker Desktop тоже должно работать, но не проверялось) |
| Docker | `docker run hello-world` выполняется без ошибок (пользователь в группе `docker` или через `sudo`) |
| Память | 50 ГБ RAM (столько использует профиль; меньше — см. «Настройка») |
| Диск | ~20 ГБ под образ + место под риды; уточнить у автора |
| Сеть | доступ к NCBI SRA и Google Drive (оттуда скачивается база SILVA, ~300 МБ) |

## Запуск

```bash
git clone <repo-url> lbp-microbio
cd lbp-microbio
git checkout docker
./run-pipeline.sh /путь/к/samples.tsv
```

`samples.tsv` вы получаете от автора отдельно — в репозитории и в образе его нет
(чувствительные данные).

Первый запуск сначала соберёт образ (20–40 минут, один раз), затем запустит
расчёт. Расчёт идёт часами; удобно запускать в `tmux`/`screen` или так:

```bash
nohup ./run-pipeline.sh /путь/к/samples.tsv > run.log 2>&1 &
tail -f run.log
```

## Результат

В папке `lbp-run/` появятся два файла — **оба** нужно передать автору:

| Архив | Путь внутри | Содержимое |
|---|---|---|
| `results.zip` | `results/` | ASV (fasta, таблица counts, таксономия), потери ридов, рисунки, QC-отчёты, PICRUSt2 |
| | `logs/` | логи всех шагов и Snakemake |
| | `run_info.txt` | версия кода, дата, код завершения |
| `data_temp.zip` | `data/temp/` | промежуточные R-объекты (`ps_raw.rds` и др.) — нужны для продолжения анализа |

> ⚠️ `ps_raw.rds` (в `data_temp.zip`) содержит метаданные образцов из `samples.tsv` —
> передавайте архивы так же, как сам `samples.tsv`.

Риды (`lbp-run/data/samples/`) в архивы не входят. После получения архивов
папку `lbp-run/` можно удалить.

## Если что-то пошло не так

- **Прервалось** (выключили машину, Ctrl+C, обрыв сети) — запустите ту же
  команду ещё раз: уже посчитанное не пересчитывается.
- **Ошибка** — архивы всё равно создаются (в `results.zip` — логи); пришлите
  оба автору. Последние строки вывода тоже полезны.
- **Проверить без расчёта**, что всё настроено: `./run-pipeline.sh samples.tsv --dry-run`
  — покажет список шагов.

## Настройка

Дополнительные аргументы после `samples.tsv` передаются в Snakemake:

```bash
./run-pipeline.sh samples.tsv --cores 16                    # ограничить число ядер
./run-pipeline.sh samples.tsv --resources mem_mb=30000      # меньше памяти
LBP_WORKDIR=/data/lbp-run ./run-pipeline.sh samples.tsv     # рабочая папка на другом диске
```

По умолчанию используются все ядра, доступные контейнеру, и 50 ГБ RAM
(`workflow/profiles/docker/config.yaml`).

## Для автора: как это устроено

- `Dockerfile` — образ на основе `ghcr.io/prefix-dev/pixi`: pixi-окружение
  `runner` (Snakemake + conda) и заранее собранные conda-окружения правил в
  `/opt/snakemake-conda`. Данные в образ не попадают: `.dockerignore` пропускает
  только код, последняя команда сборки падает, если найдёт sample sheet,
  `.dta`/`.xlsx`/`.RData` или `.env`.
- `run-pipeline.sh` — собирает образ `lbp-microbio:<commit>` (новый коммит →
  новый образ), монтирует `samples.tsv` только на чтение в `/input/` и рабочую
  папку в `/work`, запускает контейнер от имени текущего пользователя.
- `docker/entrypoint.sh` — запускает Snakemake в `/work` с профилем
  `workflow/profiles/docker` и `docker/config.docker.yaml` (путь к sample sheet,
  Telegram выключен), затем `docker/pack_results.py` собирает `results.zip` и `data_temp.zip`.
- Пути в архивах — относительно корня репозитория: `unzip results.zip -d <repo>`
  и `unzip data_temp.zip -d <repo>` кладут всё на свои места.
