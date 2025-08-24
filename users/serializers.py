from __future__ import annotations

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Serializer for the `User` model used in responses."""

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "display_name",
            "avatar_url",
            "bio",
        ]
        read_only_fields = ["id", "username", "email"]


class RegisterSerializer(serializers.ModelSerializer):
    """Serializer to register a new user."""

    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["username",
                  "email",
                  "password",
                  "first_name",
                  "last_name",
                  "display_name"]

    def validate_password(self, value: str) -> str:
        validate_password(value)
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user
