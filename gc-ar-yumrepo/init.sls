{%- set default_sources = {'module' : 'gc-ar-yumrepo', 'defaults' : True, 'pillar' : True} %}
{%- from "./defaults/load_config.jinja" import config as gc_ar_yumrepo with context %}

{% if gc_ar_yumrepo.use is defined %}

{%- if grains['osmajorrelease'] < 8 %}
{% set plugin_artifact_registry_format = 'yum' %}
{% set plugin_artifact_registry_config = '/etc/yum/pluginconf.d/artifact-registry.conf' %}
{% else %}
{% set plugin_artifact_registry_format = 'dnf' %}
{% set plugin_artifact_registry_config = '/etc/dnf/plugins/artifact-registry.conf' %}
{% endif -%}

{% if gc_ar_yumrepo.use | to_bool %}

Google_Cloud_Packages_RPM_Signing_Key:
  rpm_.imported_gpg_key:
    - key_path: {{ gc_ar_yumrepo.gc_ar_packages_rpm_signing_key }}

google-cloud-artifact-registry-plugin:
  pkgrepo.managed:
    - humanname: Artifact Registry Plugin
    - baseurl: https://packages.cloud.google.com/yum/repos/{{ plugin_artifact_registry_format }}-plugin-artifact-registry-el$releasever-stable
    - gpgkey: {{ gc_ar_yumrepo.ar_plugin_gpgkey }}
    - gpgcheck: 1

{{ plugin_artifact_registry_format }}-plugin-artifact-registry:
  pkg.installed:
    - refresh: true
    - require:
      - Google_Cloud_Packages_RPM_Signing_Key
      - pkgrepo: google-cloud-artifact-registry-plugin

{{ gc_ar_yumrepo.service_account_file_path }}:
  file.managed:
    - contents: |
        {{ gc_ar_yumrepo.service_account|json }}

{{ plugin_artifact_registry_format }}-plugin-artifact-registry-config:
  file.line:
    - name: {{ plugin_artifact_registry_config }}
    - content: 'service_account_json={{ gc_ar_yumrepo.service_account_file_path }}'
    - mode: ensure
    - after: "#service_account_json.*"
    - require:
      - pkg: {{ plugin_artifact_registry_format }}-plugin-artifact-registry
      - file: {{ gc_ar_yumrepo.service_account_file_path }}

{{ gc_ar_yumrepo.repository_name }}:
  pkgrepo.managed:
    - baseurl: https://{{ gc_ar_yumrepo.location }}-yum.pkg.dev/projects/{{ gc_ar_yumrepo.project_name }}/{{ gc_ar_yumrepo.repository_name }}
    - repo_gpgcheck: 0
    - gpgcheck: 0
    - require:
      - file: {{ plugin_artifact_registry_format }}-plugin-artifact-registry-config

{% if gc_ar_yumrepo.install_packages is defined %}

{{ gc_ar_yumrepo.repository_name }}-install-packages:
  pkg.installed:
    - pkgs: {{ gc_ar_yumrepo.install_packages|json }}
    - refresh: true
    - require:
      - {{ gc_ar_yumrepo.repository_name }}

{% endif %}

{% else %}

{% if gc_ar_yumrepo.install_packages is defined %}

{{ gc_ar_yumrepo.repository_name }}-install-packages:
  pkg.removed:
    - pkgs: {{ gc_ar_yumrepo.install_packages|json }}
    - required_in:
      - pkgrepo: {{ gc_ar_yumrepo.repository_name }}

{% endif %}

{{ gc_ar_yumrepo.repository_name }}:
  pkgrepo.absent:
    - required_in:
      - file: {{ gc_ar_yumrepo.service_account_file_path }}

{{ gc_ar_yumrepo.service_account_file_path }}:
  file.absent:
    - required_in:
      - pkg: {{ plugin_artifact_registry_format }}-plugin-artifact-registry

{{ plugin_artifact_registry_format }}-plugin-artifact-registry:
  pkg.removed:
    - required_in:
      - removed_Google_Cloud_Packages_RPM_Signing_Key

google-cloud-artifact-registry-plugin:
  pkgrepo.absent:
    - required_in:
      - Google_Cloud_Packages_RPM_Signing_Key

Google_Cloud_Packages_RPM_Signing_Key:
  rpm_.removed_gpg_key:
    - key_path: {{ gc_ar_yumrepo.gc_ar_packages_rpm_signing_key }}

{% endif %}

{% endif %}