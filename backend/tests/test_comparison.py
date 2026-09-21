from datetime import date
import pytest
from fastapi import HTTPException
from app.services import executive_service as svc


def test_comparison_zero_baseline_and_same_scope(monkeypatch):
    calls = []
    results = iter([{'total':0,'activas':0,'resueltas':0}, {'total':4,'activas':1,'resueltas':3}])
    def query(db, sql, params):
        calls.append(params)
        assert 'm.entidad_id=:entidad_id' in sql
        return [next(results)]
    monkeypatch.setattr(svc,'query_rows',query)
    result = svc.compare_periods(None,{'entidad_id':1},{'municipio_id':2,'fecha_inicio':date(2020,1,1)},
        date(2024,2,1),date(2024,2,29),date(2025,2,1),date(2025,2,28))
    assert result['variacion']['total']=={'diferencia':4,'porcentaje':None}
    assert all(p['municipio_id']==2 and p['entidad_id']==1 for p in calls)
    assert calls[0]['fecha_fin']==date(2024,2,29)
    assert calls[1]['fecha_inicio']==date(2025,2,1)


@pytest.mark.parametrize('a,b,expected',[(10,5,-50.0),(5,10,100.0),(0,0,0),(3,3,0)])
def test_variation(monkeypatch,a,b,expected):
    values=iter([a,b])
    monkeypatch.setattr(svc,'query_rows',lambda *args:[dict.fromkeys(['total','activas','resueltas'],next(values))])
    d=date(2025,1,1)
    assert svc.compare_periods(None,{'entidad_id':1},{},d,d,d,d)['variacion']['total']['porcentaje']==expected


def test_invalid_period():
    with pytest.raises(HTTPException) as err:
        svc.compare_periods(None,{}, {},date(2025,2,1),date(2025,1,1),date(2024,1,1),date(2024,12,31))
    assert err.value.status_code==422
