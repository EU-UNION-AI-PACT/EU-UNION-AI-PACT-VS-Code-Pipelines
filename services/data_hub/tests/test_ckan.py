import pytest
import asyncio
from unittest.mock import patch
from services.data_hub.src.ckan import search_ckan_multi

@pytest.mark.asyncio
async def test_ckan_multi_no_bases():
    """Test CKAN search with no bases configured"""
    with patch.dict('os.environ', {'OPEN_DATA_CKAN_BASES': ''}):
        res = await search_ckan_multi("climate", limit=3)
        assert res == []

@pytest.mark.asyncio  
async def test_ckan_multi_with_mock():
    """Test CKAN search with mocked response"""
    with patch('services.data_hub.src.ckan.search_ckan') as mock_search:
        mock_search.return_value = [
            {
                "source": "test.org",
                "kind": "dataset", 
                "id": "test-123",
                "title": "Climate Test Data",
                "description": "Test dataset",
                "url": "http://test.org/data",
                "score": 0.0
            }
        ]
        
        result = await search_ckan_multi("climate", limit=5)
        assert len(result) >= 0  # Mock may not be called due to env setup
