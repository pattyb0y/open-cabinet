#!/bin/bash -ex

export vpc_label=${name_of_jenkins_stack/-*/}

#when all pipelines have updated bundler, this can happens at the user level
#bundler config --local mirror.http://rubygems.org http://${vpc_label,,}-nexus.${domain}/nexus/content/repositories/rubygemsproxy/
#bundler config --local mirror.https://rubygems.org http://${vpc_label,,}-nexus.${domain}/nexus/content/repositories/rubygemsproxy/

bundle install --jobs 4 \
               --gemfile=$(dirname $0)/Gemfile \
               --retry 10

gem install myuscis-common-pipeline-0.0.30.gem

source $(gem contents myuscis-common-pipeline | grep common-bash-functions)

confirm_env_vars_available 'sdb_domain region pipeline_instance_id'

####################################

function create_secrets {
  set +x
  cat <<SECRETS > secret.values
  environment: default
  secret_key_base: b46c819adc1362197155e3f07d3c68edaaa4bd43910e42e16a035e34d7b3e41e324c3a4e753935d9b0377ac4672178b2e26365e6a8e337beae2ee2bba671795c
  db_host: $(get_db_hostname --region ${region} --stackname $(get_pipeline_property --key open_cabinet_rds_stack_name))
  db_un: dbuser
  db_pw: dbpassword
  un: user
  pw: password
  import_key: tQ2ILy9FhJedWF2iH09nwIKdNV7eEhMXsz4c8zef

development: *default
SECRETS
  set -x

  render_template --template-path '.pipeline/config/secrets.yml.erb' \
                  --output-path 'config/secrets.yml' \
                  --values-path secret.values

  rm secret.values
}

bundle install --jobs 4 --retry 10

export target_env=development

cp config/environments/development.rb.sample config/environments/development.rb
$(dirname $0)/verify-or-create-database.sh
create_secrets


#bundle exec rake db:migrate:reset RAILS_ENV=test
#bundle exec rake test:unit RAILS_ENV=test
bundle exec rake db:migrate
bundle exec rspec

set_pipeline_property --key furthest_pipeline_stage_completed \
                      --value build

set_pipeline_property --key production_candidate \
                      --value false