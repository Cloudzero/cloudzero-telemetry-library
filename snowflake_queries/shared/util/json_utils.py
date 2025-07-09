# Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
# Licensed under the BSD-style license. See LICENSE file in the project root for full license information.

"""
JSON utilities for CloudZero telemetry serialization.
Handles datetime, decimal, enum, and UUID serialization.
"""

import json
from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Any
from uuid import UUID

try:
    import simplejson
    HAS_SIMPLEJSON = True
except ImportError:
    HAS_SIMPLEJSON = False


class ExtendedEncoder(json.JSONEncoder):
    """JSON encoder with support for extended types."""
    
    def default(self, obj):
        """Handle serialization of extended types."""
        if isinstance(obj, Decimal):
            return str(obj)
        elif isinstance(obj, Enum):
            return obj.value
        elif isinstance(obj, datetime):
            return obj.isoformat()
        elif isinstance(obj, UUID):
            return str(obj)
        else:
            return super().default(obj)


def dumps(obj: Any, **kwargs) -> str:
    """
    Serialize object to JSON string with extended type support.
    
    Args:
        obj: Object to serialize
        **kwargs: Additional arguments passed to json.dumps
        
    Returns:
        JSON string
    """
    if HAS_SIMPLEJSON:
        # Use simplejson if available for better performance
        return simplejson.dumps(obj, **{
            'cls': ExtendedEncoder,
            'use_decimal': False,
            'iterable_as_array': True,
            **kwargs
        })
    else:
        # Fall back to standard library json
        return json.dumps(obj, cls=ExtendedEncoder, **kwargs)


def loads(s: str, **kwargs) -> Any:
    """
    Deserialize JSON string to object.
    
    Args:
        s: JSON string to deserialize
        **kwargs: Additional arguments passed to json.loads
        
    Returns:
        Deserialized object
    """
    if HAS_SIMPLEJSON:
        return simplejson.loads(s, **kwargs)
    else:
        return json.loads(s, **kwargs)


def serializable(obj: Any) -> Any:
    """
    Make object serializable by converting to JSON and back.
    
    Args:
        obj: Object to make serializable
        
    Returns:
        Serializable representation of object
    """
    return loads(dumps(obj))


def safe_loads(s: str, default: Any = None) -> Any:
    """
    Safely deserialize JSON string with fallback.
    
    Args:
        s: JSON string to deserialize
        default: Default value if parsing fails
        
    Returns:
        Deserialized object or default value
    """
    try:
        return loads(s)
    except (json.JSONDecodeError, TypeError, ValueError):
        return default


def pretty_dumps(obj: Any, **kwargs) -> str:
    """
    Serialize object to pretty-printed JSON string.
    
    Args:
        obj: Object to serialize
        **kwargs: Additional arguments passed to dumps
        
    Returns:
        Pretty-printed JSON string
    """
    return dumps(obj, indent=2, sort_keys=True, **kwargs)


def validate_json(s: str) -> bool:
    """
    Validate if string is valid JSON.
    
    Args:
        s: String to validate
        
    Returns:
        True if valid JSON, False otherwise
    """
    try:
        loads(s)
        return True
    except (json.JSONDecodeError, TypeError, ValueError):
        return False


def extract_json_from_string(s: str, start_marker: str, end_marker: str) -> Any:
    """
    Extract and parse JSON from string between markers.
    
    Args:
        s: String to search
        start_marker: Start marker for JSON
        end_marker: End marker for JSON
        
    Returns:
        Parsed JSON object or None if not found/invalid
    """
    try:
        start_idx = s.find(start_marker)
        if start_idx == -1:
            return None
        
        start_idx += len(start_marker)
        end_idx = s.find(end_marker, start_idx)
        if end_idx == -1:
            return None
        
        json_str = s[start_idx:end_idx]
        return loads(json_str)
        
    except (json.JSONDecodeError, TypeError, ValueError):
        return None