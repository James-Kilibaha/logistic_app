"""
Platform admin (wewe): kuingia, wasaidizi, na takwimu za mfumo mzima (dashboard ya admin panel).
Token ya platform ina `type=platform` - haitumiki kwenye API za kampuni, na token za kampuni hazitumiki hapa.
"""
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy import func
from sqlalchemy.orm import Session

from ... import config
from ...core import audit, ratelimit
from ...core.base_model import utc_now
from ...core.exceptions import BadRequest, Conflict, NotFound
from ...core.security import hash_password, password_problem, verify_password
from . import schema
from .dao import PlatformAdminDao
from .model import PlatformAdmin

# /api/platform/token: fomu ya "Authorize" kwenye /docs (Swagger)
_oauth2 = OAuth2PasswordBearer(tokenUrl="/api/platform/token", scheme_name="PlatformAdmin")


def _token(admin: PlatformAdmin) -> schema.LoginResponse:
    minutes = max(config.ACCESS_TOKEN_EXPIRE_MINUTES, 60) * 4
    claims = {"pid": str(admin.id), "sub": admin.username, "ver": int(admin.tokenVersion or 0), "type": "platform",
              "exp": datetime.now(timezone.utc) + timedelta(minutes=minutes)}
    return schema.LoginResponse(access_token=jwt.encode(claims, config.SECRET_KEY, algorithm=config.ALGORITHM),
                                expires_in=minutes * 60, admin=schema.AdminOut.model_validate(admin))


def current_admin(token: str = Depends(_oauth2)) -> PlatformAdmin:
    """Dependency ya endpoints zote za /api/platform."""
    from ...db import SessionLocal

    error = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not validate credentials",
                          headers={"WWW-Authenticate": "Bearer"})
    try:
        payload = jwt.decode(token, config.SECRET_KEY, algorithms=[config.ALGORITHM])
    except JWTError:
        raise error
    if payload.get("type") != "platform" or not payload.get("pid"):
        raise error
    db = SessionLocal()
    try:
        admin = PlatformAdminDao(db).get(payload["pid"])
    finally:
        db.close()
    if admin is None or not admin.active or int(admin.tokenVersion or 0) != int(payload.get("ver") or 0):
        raise error
    return admin


def login(db: Session, data: schema.Login, ip: str | None) -> schema.LoginResponse:
    username = data.username.strip()
    key = f"platform:{username.lower()}"
    ratelimit.check(key, ip)
    admin = PlatformAdminDao(db).by_username(username)
    if admin is None or not admin.active or not verify_password(data.password, admin.password):
        ratelimit.failed(key, ip)
        audit.write(user_id=admin.id if admin else None, username=username[:100], module="platform", action="LOGIN",
                    method="POST", path="/api/platform/login", entity_id=None, status_code=401, ip=ip,
                    summary="Platform admin: nywila au jina si sahihi", detail=None)
        raise NotFound("Incorrect username or password")
    ratelimit.succeeded(key)
    admin.lastLoginAt = utc_now()
    db.commit()
    db.refresh(admin)
    return _token(admin)


def change_password(db: Session, admin_id, data: schema.ChangePassword) -> schema.LoginResponse:
    admin = PlatformAdminDao(db).get(admin_id)
    if admin is None or not verify_password(data.oldPassword, admin.password):
        raise BadRequest("Current password is not correct")
    problem = password_problem(data.newPassword)
    if problem:
        raise BadRequest(problem)
    admin.password = hash_password(data.newPassword)
    admin.tokenVersion = int(admin.tokenVersion or 0) + 1
    db.commit()
    db.refresh(admin)
    return _token(admin)


def list_admins(db: Session) -> list[PlatformAdmin]:
    return PlatformAdminDao(db).ordered()


def create_admin(db: Session, data: schema.AdminCreate) -> PlatformAdmin:
    dao = PlatformAdminDao(db)
    if dao.by_username(data.username):
        raise Conflict("Jina hili la mtumiaji lipo tayari")
    problem = password_problem(data.password)
    if problem:
        raise BadRequest(problem)
    return dao.create(username=data.username.strip(), password=hash_password(data.password),
                      fullName=data.fullName.strip(), phone=data.phone, email=data.email, active=True)


def update_admin(db: Session, data: schema.AdminUpdate, me_id) -> PlatformAdmin:
    dao = PlatformAdminDao(db)
    admin = dao.get(data.id)
    if admin is None:
        raise NotFound("Msimamizi hayupo")
    if admin.id == me_id and not data.active:
        raise BadRequest("Huwezi kujizuia mwenyewe")
    admin.fullName, admin.phone, admin.email = data.fullName.strip(), data.phone, data.email
    if admin.active != data.active:
        admin.active = data.active
        admin.tokenVersion = int(admin.tokenVersion or 0) + 1
    if data.password:
        problem = password_problem(data.password)
        if problem:
            raise BadRequest(problem)
        admin.password = hash_password(data.password)
        admin.tokenVersion = int(admin.tokenVersion or 0) + 1
    db.commit()
    db.refresh(admin)
    return admin


def seed_from_env(db: Session) -> None:
    """Msimamizi wa kwanza wa platform kutoka `.env` (ADMIN_USERNAME/ADMIN_PASSWORD) kama hakuna yeyote."""
    import logging

    log = logging.getLogger(__name__)
    dao = PlatformAdminDao(db)
    if dao.count() > 0:
        return
    if not (config.ADMIN_USERNAME and config.ADMIN_PASSWORD):
        log.warning("HAKUNA SUPER ADMIN: weka ADMIN_USERNAME na ADMIN_PASSWORD kwenye .env na uwashe server upya, "
                    "au endesha:  python -m logistic.saas.admin create <username> <password>")
        return
    problem = password_problem(config.ADMIN_PASSWORD)
    if problem:
        log.warning("Super admin HAJAUNDWA - ADMIN_PASSWORD ya .env haikubaliki: %s", problem)
        return
    dao.create(username=config.ADMIN_USERNAME.strip(), password=hash_password(config.ADMIN_PASSWORD),
               fullName=f"{config.ADMIN_FIRST_NAME} {config.ADMIN_LAST_NAME}".strip(), phone=config.ADMIN_PHONE,
               active=True)
    log.info("Super admin '%s' ameundwa kutoka .env", config.ADMIN_USERNAME)


def reset_tenant_password(db: Session, company_id, data: schema.ResetTenantPassword) -> dict:
    from ...core import tenant
    from ...db import SessionLocal
    from ...user.dao import UserDao

    problem = password_problem(data.newPassword)
    if problem:
        raise BadRequest(problem)
    with tenant.use_company(company_id):
        tdb = SessionLocal()
        try:
            user = UserDao(tdb).by_username(data.username.strip())
            if user is None:
                raise NotFound("Mtumiaji hayupo kwenye kampuni hii")
            user.password = hash_password(data.newPassword)
            user.mustChangePassword = True
            user.active = 1
            user.tokenVersion = int(user.tokenVersion or 0) + 1
            user.otpAttempts = 0
            tdb.commit()
            ratelimit.succeeded(user.username)
        finally:
            tdb.close()
    return {"ok": True, "username": data.username.strip()}


def tenant_users(db: Session, company_id) -> list[dict]:
    from ...user.model import User

    rows = (db.query(User).filter(User.company_id == company_id).order_by(User.firstName).all())
    return [{"id": str(u.id), "username": u.username, "name": f"{u.firstName} {u.lastName}",
             "phone": u.phoneNumber, "active": bool(u.active), "created_at": u.created_at} for u in rows]


def dashboard(db: Session) -> dict:
    """Takwimu za admin panel yako: kampuni, subscription, mapato."""
    from ..company.model import Company
    from ..subscription import service as subscriptions
    from ..subscription.model import SubscriptionPayment

    companies = db.query(Company).all()
    counts = {"total": len(companies), "active": 0, "suspended": 0, "pending": 0, "rejected": 0, "trial": 0,
              "paying": 0, "grace": 0, "expired": 0, "none": 0, "expiringSoon": 0}
    awaiting = []
    expiring = []
    mrr = 0.0
    for company in companies:
        if company.status == "SUSPENDED":
            counts["suspended"] += 1
            continue
        if company.status == "REJECTED":
            counts["rejected"] += 1
            continue
        if company.status == "PENDING":
            counts["pending"] += 1
            awaiting.append({"id": str(company.id), "name": company.name, "slug": company.slug,
                             "phone": company.phone, "ownerName": company.ownerName,
                             "created_at": company.created_at.isoformat() if company.created_at else None})
            continue
        counts["active"] += 1
        st = subscriptions.compute(db, company.id)
        key = {"TRIAL": "trial", "ACTIVE": "paying", "GRACE": "grace", "EXPIRED": "expired"}.get(st["status"], "none")
        counts[key] += 1
        if st["status"] == "ACTIVE" and st["plan"]:
            mrr += float(st["plan"]["price"] or 0) / max(int(st["plan"]["months"] or 1), 1)
        if st["status"] in ("TRIAL", "ACTIVE", "GRACE") and st["daysLeft"] is not None and st["daysLeft"] <= 7:
            counts["expiringSoon"] += 1
            expiring.append({"id": str(company.id), "name": company.name, "slug": company.slug,
                             "status": st["status"], "endsAt": st["endsAt"], "daysLeft": st["daysLeft"]})
    month_start = utc_now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    revenue = (db.query(SubscriptionPayment.currency, func.sum(SubscriptionPayment.amount))
               .filter(SubscriptionPayment.status == "CONFIRMED", SubscriptionPayment.reviewedAt >= month_start)
               .group_by(SubscriptionPayment.currency).all())
    pending = db.query(func.count(SubscriptionPayment.id)).filter(SubscriptionPayment.status == "PENDING").scalar()
    since = utc_now() - timedelta(days=30)
    new_companies = sum(1 for c in companies if c.created_at and c.created_at >= since)
    return {
        "companies": counts,
        "newCompanies30d": new_companies,
        "pendingPayments": int(pending or 0),
        "revenueThisMonth": [{"currency": c, "amount": float(a or 0)} for c, a in revenue],
        "mrrTzs": round(mrr),
        "expiring": sorted(expiring, key=lambda r: r["daysLeft"]),
        "awaitingApproval": sorted(awaiting, key=lambda r: r["created_at"] or "", reverse=True),
    }
