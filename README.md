# BugTracker - Систем за праћење грешака у софтверу

Пројекат 10 из предмета **Програмирање репозиторијума података**, ФОН.
SQL Server 2022 + две конзолне C# апликације.

---

## Шта се предаје - мапа према списку из документације (одељак 4)

| # | Ставка из документације | Где се налази |
|---|---|---|
| 1 | SQL скрипта за креирање базе, схема, улога и корисника | `db/01_baza_i_seme.sql` |
| 2 | SQL скрипта за креирање табела са свим ограничењима (impl слој) | `db/02_tabele.sql`, `db/03_impl_interno.sql` |
| 3 | SQL скрипта за унос демо података **са верификационим тестовима** | `db/04_demo_podaci.sql` (тестови V1-V7 на крају) |
| 4 | SQL скрипте **за сваки захтев засебно** | `db/05` ... `db/14` - по једна скрипта по захтеву, види табелу ниже |
| 5 | C# assembly пројекат са CLR функцијама | `clr/BugTrackerCLR/` |
| 6 | Кратак опис решења по захтеву | `docs/OpisResenja.md` и одељак 3.1 документације |
| 7 | Тест SQL скрипте које демонстрирају сваки захтев | `tests/T01` ... `tests/T14` |
| 8 | Апликације у C# | `apps/ApplicationDEV`, `apps/ApplicationQA` |

---

## Скрипта по захтеву

Свака скрипта у `db/` покрива један захтев и креира објекте кроз све слојеве
(`impl` → `spec` → `api_*`) за ту функционалност. Редослед покретања је важан:
Full-Text индекси морају постојати пре функција које користе `CONTAINSTABLE`,
а CLR агрегат пре погледа који га зове.

| Скрипта | Захтев | Шта прави |
|---|---|---|
| `01_baza_i_seme.sql` | 1 | база, колација, четири схеме, логини, апликационе улоге |
| `02_tabele.sql` | 2 | пет табела, 27 ограничења, четири индекса, `fnsImaTekst` |
| `03_impl_interno.sql` | 2 | `vwKomentarDetalji`, `uprLogujGresku`, тригер `trgAutoStatusResen` |
| `04_demo_podaci.sql` | 1 | демо подаци из табела 1-3 + верификациони тестови |
| `05_fulltext.sql` | 6, 7 | каталог `ftBugTracker` и три Full-Text индекса |
| `06_clr_uda.sql` | 8 | CLR склоп, агрегат `SpojPoruke`, екран „сажетак по пројекту“ |
| `07_upravljanje_greskama.sql` | 3 | `upr_PrijaviGresku`, `upr_DodajKomentar`, `upr_PromeniStatus` |
| `08_pregledi.sql` | 4 | `vw_GRESKA`, `vw_KOMENTAR`, `vw_OTVORENE_GRESKE` + `api_` омотачи |
| `09_istorija_statusa.sql` | 13 | `OUTPUT` клаузула у процедури и у тригеру, поглед историје |
| `10_pretraga.sql` | 6, 7 | `CONTAINS` и `FREETEXT` функције, `upr_PretraziGreske` |
| `11_izvestaji_xml.sql` | 9, 10 | FLWOR извештај, осе `child::`/`descendant-or-self::`/`parent::` |
| `12_pretraga_komentara.sql` | 11 | `upr_NadjiPoTerminu` - `CONTAINS` + `xml.nodes()` |
| `13_matrica_gresaka.sql` | 12 | `upr_MatricaGresaka` - PIVOT |
| `14_dozvole.sql` | 5 | `GRANT`/`DENY`, изолација слојева |

Тестови прате исту поделу: `tests/T01`-`T13` по захтеву, плус
`tests/T14_nefunkcionalni_zahtevi.sql` за нефункционалне захтеве НЗ 1-8
(колација, смер зависности између слојева, шифровање `spec`-а, правила
именовања, права улога).

---

## Покретање

```bash
./scripts/db-up.sh        # подиже SQL Server у контејнеру и чека да буде спреман
./scripts/reset-all.sh    # гради целу базу од нуле, свих 14 скрипти редом
./scripts/test-all.sh     # покреће све тестове, излаз у tests/izlaz/
./scripts/app-dev.sh      # апликација програмера
./scripts/app-qa.sh       # QA апликација
```

## Документација и презентација

| Фајл | Шта је |
|---|---|
| `docs/PRP_Projekat_10_BugTracker.docx` | документација пројекта, попуњена |
| `docs/PRP_Prezentacija_BugTracker.pptx` | презентација за одбрану, по прослеђеном шаблону |
| `docs/OpisResenja.md` | кратак опис решења по захтеву |
| `docs/slike/` | ДЕР, архитектура базе и слојеви апликације |

## Апликације

Обе су конзолне, са менијем, и обе су подељене на три слоја како траже НЗ 9 и 10:

| Фолдер | Слој | Шта зна |
|---|---|---|
| `Model/` | домен | само класе са подацима, не зна ни за базу ни за екран |
| `Podaci/` | приступ подацима | једино место које зна за `SqlConnection`; зове само своју `api_` схему |
| `Ui/` | приказ | зна за домен и за слој испод, али ниједан ред SQL-а не пише |

Свака се повезује логином који **нема никаква права**, па позове
`sp_setapprole`. Тек тада добија приступ, и то само својој схеми. На почетку
исписује идентитет сесије (`AppLoginDEV -> DataProviderDEV`), што је уједно и
доказ да улога замењује корисника.

QA апликација има и ставку „Провера граница приступа“ која намерно покуша оно
што не сме (`impl`, `spec`, туђи `api_dev`) и прикаже шта је сервер одговорио.

Појединачно:

```bash
./scripts/sql.sh -f db/13_matrica_gresaka.sql
./scripts/sql.sh -d BugTracker -q "EXEC api_qa.upr_MatricaGresaka;"
```

CLR склоп се гради засебно (`./scripts/build-clr-only.sh`), а `reset-all.sh` то
ради сам.

---

## Окружење

SQL Server нема ARM издање, а рачунар је Apple Silicon. Зато иде кроз
**Colima** (Linux VM преко `Virtualization.framework`) уз **Rosetta 2**, која
преводи x86_64 инструкције. Azure SQL Edge, који јесте ARM, отпада јер нема ни
Full-Text Search ни CLR - а то су захтеви 6, 7, 8 и 11.

Званична Microsoft слика не садржи Full-Text Search (на Linux-у је то посебан
пакет), па се гради сопствена: `scripts/Dockerfile` додаје `mssql-server-fts`.

---

## Архитектура укратко

```
ApplicationDEV ──> api_dev ─┐
                            ├──> spec ──> impl ──> табеле
ApplicationQA  ──> api_qa  ─┘
```

Апликација се повеже логином који **нема никаква права**, па позове
`sp_setapprole`. Тек тада добија приступ, и то само својој `api_` схеми.
Директан приступ табелама је одбијен; кроз поглед пролази, јер су све схеме у
власништву `dbo` (*ownership chaining*). Провера је у
`tests/T05_izolacija_DEV.sql` и `tests/T05_izolacija_QA.sql`.
