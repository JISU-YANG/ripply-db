# ripply-db

Ripply 서비스의 Supabase 데이터베이스 마이그레이션 저장소입니다.

**연결된 Supabase 프로젝트:** `idepybnaqvxkcwbtjirp`

## 구조

```
supabase/
├── config.toml
└── migrations/     # SQL 마이그레이션 파일
```

## 로컬 개발

```bash
# Supabase CLI 로그인
export SUPABASE_ACCESS_TOKEN=your_token

# 프로젝트 연결
supabase link --project-ref idepybnaqvxkcwbtjirp

# 로컬 Supabase 시작 (선택)
supabase start

# 새 마이그레이션 생성
supabase migration new my_change

# 원격 DB에 적용
supabase db push
```

## GitHub ↔ Supabase 연동

Supabase Dashboard에서 이 저장소를 연결합니다:

1. [Integrations](https://supabase.com/dashboard/project/idepybnaqvxkcwbtjirp/settings/integrations) 접속
2. **GitHub Integration** → Authorize GitHub
3. Repository: `JISU-YANG/ripply-db`
4. Working directory: `.`
5. **Deploy to production** 활성화
6. **Enable integration**

`main` 브랜치에 push하면 마이그레이션이 자동으로 프로덕션 DB에 적용됩니다.

## 앱 저장소

프론트엔드/API: [ripply-app](https://github.com/JISU-YANG/ripply-app)
