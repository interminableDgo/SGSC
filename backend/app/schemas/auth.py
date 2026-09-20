from pydantic import BaseModel, EmailStr, Field


class EmailInput(BaseModel):
    correo: EmailStr = Field(max_length=180)


class LoginInput(EmailInput):
    password: str = Field(min_length=1, max_length=128)


class RegisterInput(EmailInput):
    password: str = Field(min_length=15, max_length=128)


class ResetInput(BaseModel):
    token: str = Field(min_length=32, max_length=200)
    password: str = Field(min_length=15, max_length=128)


class VerifyInput(BaseModel):
    token: str = Field(min_length=32, max_length=200)
    code: str = Field(pattern=r'^\d{6}$')
