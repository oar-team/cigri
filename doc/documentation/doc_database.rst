.. -*- rst-mode -*-

Database documentation
======================

Database type
-------------

Cigri supports both Mysql and PostgreSQL databases. Their access is
transparent, only the initial setup differs.

Quick notes
-----------

- The "properties" field of the "clusters" table currently only supports "property1='value1' 
  AND property2='value2'" form (no "OR" allowed) because it is not directly used as SQL, but
  parsed.

.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
