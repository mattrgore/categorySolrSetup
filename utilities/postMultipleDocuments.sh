curl -X POST -H 'Content-Type: application/json' 'http://localhost:8983/solr/category/update' --data-binary '
[
  {
    "id": "1",
    "original description": "hat hat hat hat boys cap baseball small boy"
  },
  {
    "id": "2",
    "original description": "dress dress dress long girls skirt small girl"
  },
  {
    "id": "3",
    "original description": "dress dress long girls skirt small girl"
  }
]'