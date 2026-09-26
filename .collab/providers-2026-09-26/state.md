# providers-2026-09-26 - wiring and comparing plan routes

## Round 1 - Alibaba Model Studio Token Plan (wave 22) and a route comparison (2026-09-26)

- The maintainer subscribed to the Token Plan Personal Edition (Lite, Singapore). The plan's own
  key (`sk-sp-...`) lives in `ALIBABA_API_KEY`; provider table `[model_providers.alibaba]` on
  `https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1`, wire `responses`.
  A first attempt stored a 30-character value (the length of an AccessKey Secret) and the
  endpoint answered 401 InvalidApiKey; the plan key works.
- Wave 22 declares the host in caps-v1 (vocabulary `alibaba`, 11 exact text models,
  `prompt-only`); undeclared hosts are listed in ordinal order in the refusal message.
- The same narrow checkpoint (read only the caps-v1 table, judge the new entry), effort medium
  (sent medium on both plans), daytime rates:

  | n | route | model | wall | input (cached) | output | result |
  |---|---|---|---|---|---|---|
  | 1 | alibaba | qwen3.8-max | 158 s | 217k (114k) | 4.1k | ADVISE, F01-1 minor, F01-2 note |
  | 2 | alibaba | deepseek-v4.1-flash | 213 s | 344k (286k) | 7.1k | ADVISE |
  | 3 | byteplus | deepseek-v4.1-flash | 58 s | 407k (394k) | 4.0k | ADVISE |

  The Alibaba console moved from 0.25% to 1.92% of the Lite month (11,500 credits) for runs 1-2,
  i.e. about 190 credits for two narrow checkpoints. BytePlus counts requests (Lite 1200 per 5 h),
  so token-heavy agentic reviews are far cheaper there, and deepseek-v4.1-flash answered 3.7x
  faster. Conclusion: DeepSeek stays on BytePlus; Alibaba is the Qwen 3.8 route, weighty only,
  best at Beijing night (16:00-02:00 CEST) when qwen3.8 costs 40% less.
- F01-1 (the `auto` router declared with a verbatim xhigh) and F01-2 (the caps-v1 header comment
  lacked the new host - and BytePlus and Kimi) were fixed in wave 22 itself.
