-- ==============================================================================
-- 研修アプリ (training-app) データベーススキーマ
-- Supabase の SQL Editor に貼り付けて「RUN」を実行してください
-- ==============================================================================

-- 1. Profiles テーブル（ユーザー属性管理）
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  full_name text,
  role text default 'employee' check (role in ('admin', 'employee')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS（行レベルセキュリティ）を有効化
alter table public.profiles enable row level security;

create policy "Users can view own profile" 
  on public.profiles for select 
  using (auth.uid() = id);

create policy "Users can update own profile" 
  on public.profiles for update 
  using (auth.uid() = id);

-- 新規ユーザー登録時に自動で profiles にレコードを作成するトリガー
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)));
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. Training Responses テーブル（研修振り返り・評価データ 8設問）
create table if not exists public.training_responses (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  session_date date not null default current_date,
  q1_score integer check (q1_score between 1 and 5) not null, -- 大きな声で挨拶ができたか？
  q2_score integer check (q2_score between 1 and 5) not null, -- 笑顔・表情
  q3_score integer check (q3_score between 1 and 5) not null, -- 身だしなみ・清潔感
  q4_score integer check (q4_score between 1 and 5) not null, -- 時間厳守・事前準備
  q5_score integer check (q5_score between 1 and 5) not null, -- 相手の目を見て話す・傾聴
  q6_score integer check (q6_score between 1 and 5) not null, -- 適切な言葉遣い（敬語など）
  q7_score integer check (q7_score between 1 and 5) not null, -- 指示・質問のメモ取り
  q8_score integer check (q8_score between 1 and 5) not null, -- 報告・連絡・相談（報連相）の徹底
  reflection_note text,                                      -- 振り返り・今後の意気込みコメント
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- インデックス
create index if not exists idx_training_responses_user_date on public.training_responses (user_id, session_date desc);

-- RLS（行レベルセキュリティ）を有効化
alter table public.training_responses enable row level security;

-- 自分が回答したデータのみ参照可能
create policy "Users can view own training responses"
  on public.training_responses for select
  using (auth.uid() = user_id);

-- 自分の回答のみ登録可能
create policy "Users can insert own training responses"
  on public.training_responses for insert
  with check (auth.uid() = user_id);
