##
## Project Makefile
##

# Split all arguments for easier use in commands.
# You can now use the variables: ${ARGS} ${ARG_1} ${ARG_2} ${ARG_3} ${ARG_REST}
# @see https://stackoverflow.com/questions/2214575/passing-arguments-to-make-run#answer-45003119
ARGS = $(filter-out $@,$(MAKECMDGOALS))
ARG_1 = $(word 1, ${ARGS})
ARG_2 = $(word 2, ${ARGS})
ARG_3 = $(word 3, ${ARGS})
ARG_4 = $(word 4, ${ARGS})
ARG_REST = $(wordlist 2, 100, ${ARGS})
VALID_ENVS := dev test

## We use the following rule/recipe to prevent errors messages when passing arguments in make commands
## @see https://stackoverflow.com/a/6273809/1826109
%:
	@:

# We want to override the default make test command.
.PHONY: tests count-five-stars

# This is a clever trick to mimic help functionality
# Execute `make` or `make help` to see all command comments that are commented with a double # symbol
# Example: `init: ## Initial installation of the project`
help: ## Available commands (default).
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS="([a-z|:]) ## "} {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

beep: ## Sygnal
	@for i in 1 2 3; do echo -e "\a"; sleep 1; done
	
site: ## Install a site.
	lando db-import ${ARG_1}.sql.gz

	#lando drush sql-sanitize --sanitize-password=no -y

	sed -i "s/\(\"INSTANCE_NAME\"[[:space:]]*:[[:space:]]*\"\)[^\"]*\(\".*\)/\1${ARG_1}\2/" env.json

	lando composer install
	
	#lando drush config:set locale.settings translation.import_enabled 0 -y
	lando drush updb -y
	lando drush cr

	lando drush cim -y
	lando drush cr
	
	lando drush cp-domain:set-hostname --url=consumer-platform.lndo.site -y
	lando drush cset tfa.settings enabled 0 -y
	lando drush cset autologout.settings enabled 0 -y
	lando drush config:delete shield.settings
	
	$(MAKE) beep
	@echo "✅ All done Site $(ARG_1)"
	
theme: ## Install a theme.
	cd web/themes
	lando npm i && lando npm run build
	cd -
	
module: ## Install a module
	lando composer require drupal/${ARG_1}
	lando drush en ${ARG_1}
	
rebuild: ## Rebuild by composer.
	rm -rf bin
	rm -rf web/core
	rm -rf web/modules/contrib
	rm -rf web/profiles/contrib
	rm -rf web/profiles/nutrition_platform
	rm -rf vendor
	
	lando composer install

start: ## Start release branch.
	git checkout release/${ARG_1}
	git pull
	lando start
	lando composer install
	lando drush deploy
	
db_export: ## Export database.
	INSTANCE_NAME=$$(sed -n 's/.*"INSTANCE_NAME"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' env.json); \
	echo "Export $$INSTANCE_NAME"; \
	lando db-export $$INSTANCE_NAME.sql
	
new: ## Create new task branch.
	BRANCH_NAME="task/cp/$(if $(ARG_3),$(ARG_3)-)$(ARG_1)-$(ARG_2)"; \
	git checkout -b $$BRANCH_NAME
	
pull: ## Get pull
	git checkout master
	git pull
	RELEASE="release/$(ARG_1)"; \
	git checkout $$RELEASE
	git pull
	
brand_corner: ## Prepare for brand corner
	git checkout master
	git pull
	$(MAKE) site ${ARG_1}
	lando drush en cp_domain_config
	@echo 'Run https://consumer-platform.lndo.site/admin/config/consumer-platform/domain/domain-config-generate'

phpcs: ## Check code style.
	#lando exec appserver -- bash scripts/coding-standards.sh bin/phpcs --path="${ARG_1}"
	lando exec appserver -- bin/phpcs --standard=grumphp_configs/phpcs/phpcs.xml --extensions=php,module,inc,install,test,profile,theme,info,md,yml ${ARG_1}

phpcbf: ## Fix code style.
	#lando exec appserver -- bash scripts/coding-standards.sh bin/phpcbf --path="${ARG_1}"
	lando exec appserver -- bin/phpcbf --standard=grumphp_configs/phpcs/phpcs.xml --extensions=php,module,inc,install,test,profile,theme,info,md,yml ${ARG_1}
	
term_auth: ## Terminus auth
	terminus auth:login --email=serhii.klietsov1@kruschecompany.com
	
term_new: ## Terminus new user
	$(MAKE) term_auth
	terminus drush $(ARG_1).$(ARG_2) -- user:create admin_multidev@test.com --mail="admin_multidev@test.com" --password="Admin_multidev2@test.com"
	terminus drush $(ARG_1).$(ARG_2) -- user-add-role administrator admin_multidev@test.com
	@echo "admin_multidev@test.com / Admin_multidev2@test.com"

term_new_mdev: ## Terminus new user for multidev
	$(MAKE) term_auth
	terminus drush $(ARG_1).$(ARG_2) -- deploy
	terminus drush $(ARG_1).$(ARG_2) -- cset tfa.settings enabled 0 -y
	terminus drush $(ARG_1).$(ARG_2) -- cp-domain:set-hostname --url=$(ARG_2)-$(ARG_1).pantheonsite.io -y
	terminus drush $(ARG_1).$(ARG_2) -- user:create admin_multidev@test.com --mail="admin_multidev@test.com" --password="Admin_multidev2@test.com"
	terminus drush $(ARG_1).$(ARG_2) -- user-add-role administrator admin_multidev@test.com
	@echo "admin_multidev@test.com / Admin_multidev2@test.com"
	
term_update_test: ## Terminus update dev, test
	$(MAKE) term_auth
	#terminus drush $(ARG_1).dev -- deploy
	terminus drush $(ARG_1).test -- deploy
	
term_update_live: ## Terminus update live
	$(MAKE) term_auth
	terminus drush $(ARG_1).live -- deploy
	
term_update_mdev: ## Terminus update multidev
	$(MAKE) term_auth
	
	terminus drush $(ARG_1).$(ARG_2) -- config:set locale.settings translation.import_enabled 0 -y
	terminus drush $(ARG_1).$(ARG_2) -- updb -y
	terminus drush $(ARG_1).$(ARG_2) -- cr

	terminus drush $(ARG_1).$(ARG_2) -- cim -y
	terminus drush $(ARG_1).$(ARG_2) -- cr
	
	#terminus drush $(ARG_1).$(ARG_2) -- deploy
	terminus drush $(ARG_1).$(ARG_2) -- cset tfa.settings enabled 0 -y
	
fox_brand: ## Local brand installation
	lando drush en fox
	lando drush fox --input="\
	SET brand TO $(ARG_1);\
	SET brand_title TO $(ARG_2);\
	\
	USE taxonomy_term.brand;\
	CREATE brand_@brand, Brand @brand;\
	SET brand_id to @id;\
	REPLACE field_domain_access WITH @brand, field_domain_source WITH @brand, field_np_teaser_title WITH @brand_title, field_np_teaser_text WITH @brand_title, field_title WITH @brand_title, field_theme WITH @brand, field_layout WITH predefined;\
	\
	USE cp_header_settings;\
	SELECT settings LIMIT 1 INTO settings_header;\
	SET settings_header.0.settings.back_main_enabled TO 1;\
	APPEND id WITH @brand, label WITH @brand_title, settings with @settings_header.0.settings;\
	REPLACE brand WITH @brand_id;\
	\
	USE cp_footer_settings;\
	SELECT settings LIMIT 1 INTO settings_footer;\
	SET settings_footer.0.settings.top_menu_label TO Popular pages;\
	SET settings_footer.0.settings.top_menu TO footer-menu;\
	SET settings_footer.0.settings.expanded_menu_label TO See mini sitemap;\
	SET settings_footer.0.settings.expanded_menu TO mini-sitemap;\
	SET settings_footer.0.settings.footer_copyright TO \"All trademarks are owned by Société des Produits Nestlé, S.A. or used with permission. © 2025. All rights reserved.\";\
	SET settings_footer.0.settings.social_links TO footer;\
	SET settings_footer.0.settings.global_brand_social_links TO footer;\
	SET settings_footer.0.settings.show_disclaimer TO 1;\
	SET settings_footer.0.settings.disclaimer_title TO Important notice;\
	SET settings_footer.0.settings.disclaimer_text.value TO \"<p>We believe that breastfeeding is the ideal nutritional start for babies and we fully support the World Health Organization's recommendation of exclusive breastfeeding for the first six months of life followed by the introduction of adequate nutritious complementary foods along with continued breastfeeding up to two years of age. We also recognize that breastfeeding is not always an option for parents, we recommend that you speak to your healthcare professional about how to feed your baby and seek advice on when to introduce complementary feeding. If you choose not to breastfeed, please remember that such a decision can be difficult to reverse and has social and financial implications. Introducing partial bottle-feeding will reduce the supply of breast milk. Infant formula should always be prepared, used and stored as instructed on the label in order to avoid risks to a baby’s health.</p>\";\
	SET settings_footer.0.settings.disclaimer_text.format TO rich_text;\
	SET settings_footer.0.settings.global_brand_label TO @brand_title is part of Nestlé FamilyNes;\
	APPEND id WITH @brand, label WITH @brand_title, settings WITH @settings_footer.0.settings;\
	REPLACE brand WITH @brand_id;\
	\
	PRINT CREATED! TYPE success;\
	PRINT Edit and publish /brand-@brand/taxonomy/term/@brand_id/edit;\
	PRINT Edit /admin/config/consumer-platform/header-and-footer-blocks/header-settings/$(ARG_1);\
	PRINT Edit /admin/config/consumer-platform/header-and-footer-blocks/footer-settings/$(ARG_1);\
	PRINT Go to /admin/config/system/site-information?domain_config_ui_domain=$(ARG_1)&domain_config_ui_language= and set /brand-$(ARG_1);\
	PRINT Go to /admin/config/system/shield?domain_config_ui_domain=$(ARG_1)&domain_config_ui_language=;\
	PRINT Go to /admin/config/domain/edit/$(ARG_1);\
	PRINT Go to /brand-$(ARG_1)/admin/structure/menu/manage/main;\
	\
	QUIT\
	"		
term_fox_brand: ## Terminus brand rollout: make term_fox_brand ascenda Ascenda dig0030342-baby-and-me-trinidad-tobago
	$(MAKE) term_auth
	terminus drush $(ARG_3).live -- en fox
	
	terminus drush $(ARG_3).live -- fox --input="\
	SET brand TO $(ARG_1);\
	SET brand_title TO $(ARG_2);\
	\
	USE taxonomy_term.brand;\
	CREATE brand_@brand, Brand @brand;\
	SET brand_id to @id;\
	REPLACE field_domain_access WITH @brand, field_domain_source WITH @brand, field_np_teaser_title WITH @brand_title, field_np_teaser_text WITH @brand_title, field_title WITH @brand_title, field_theme WITH @brand, field_layout WITH predefined;\
	\
	USE cp_header_settings;\
	SELECT settings LIMIT 1 INTO settings_header;\
	SET settings_header.0.settings.back_main_enabled TO 1;\
	APPEND id WITH @brand, label WITH @brand_title, settings with @settings_header.0.settings;\
	REPLACE brand WITH @brand_id;\
	\
	USE cp_footer_settings;\
	SELECT settings LIMIT 1 INTO settings_footer;\
	SET settings_footer.0.settings.top_menu_label TO Popular pages;\
	SET settings_footer.0.settings.top_menu TO footer-menu;\
	SET settings_footer.0.settings.expanded_menu_label TO See mini sitemap;\
	SET settings_footer.0.settings.expanded_menu TO mini-sitemap;\
	SET settings_footer.0.settings.footer_copyright TO \"All trademarks are owned by Société des Produits Nestlé, S.A. or used with permission. © 2025. All rights reserved.\";\
	SET settings_footer.0.settings.social_links TO footer;\
	SET settings_footer.0.settings.global_brand_social_links TO footer;\
	SET settings_footer.0.settings.show_disclaimer TO 1;\
	SET settings_footer.0.settings.disclaimer_title TO Important notice;\
	SET settings_footer.0.settings.disclaimer_text.value TO \"<p>We believe that breastfeeding is the ideal nutritional start for babies and we fully support the World Health Organization's recommendation of exclusive breastfeeding for the first six months of life followed by the introduction of adequate nutritious complementary foods along with continued breastfeeding up to two years of age. We also recognize that breastfeeding is not always an option for parents, we recommend that you speak to your healthcare professional about how to feed your baby and seek advice on when to introduce complementary feeding. If you choose not to breastfeed, please remember that such a decision can be difficult to reverse and has social and financial implications. Introducing partial bottle-feeding will reduce the supply of breast milk. Infant formula should always be prepared, used and stored as instructed on the label in order to avoid risks to a baby’s health.</p>\";\
	SET settings_footer.0.settings.disclaimer_text.format TO rich_text;\
	SET settings_footer.0.settings.global_brand_label TO @brand_title is part of Nestlé FamilyNes;\
	APPEND id WITH @brand, label WITH @brand_title, settings WITH @settings_footer.0.settings;\
	REPLACE brand WITH @brand_id;\
	\
	USE block_content;\
	SELECT id WHERE type=mvp_block ORDER BY id DESC LIMIT 1 INTO last_mvp_block;\
	CLONE;REPLACE info WITH Join @brand_title;\
	SET new_mvp_block TO @id;\
	\
	PRINT CREATED! TYPE success;\
	PRINT Edit and publish /brand-@brand/taxonomy/term/@brand_id/edit;\
	PRINT Edit /admin/config/consumer-platform/header-and-footer-blocks/header-settings/$(ARG_1);\
	PRINT Edit /admin/config/consumer-platform/header-and-footer-blocks/footer-settings/$(ARG_1);\
	PRINT Go to /admin/config/system/site-information?domain_config_ui_domain=$(ARG_1)&domain_config_ui_language= and set /brand-$(ARG_1);\
	PRINT Go to /admin/config/system/shield?domain_config_ui_domain=$(ARG_1)&domain_config_ui_language=;\
	PRINT Go to /admin/config/domain/edit/$(ARG_1);\
	PRINT Go to /admin/content/block/@new_mvp_block;\
	PRINT Go to /brand-$(ARG_1)/admin/structure/menu/manage/main;\
	\
	QUIT\
	"
	
	@echo 'Set domain to these pages:'
	terminus drush $(ARG_3).live -- cget system.site page.403
	terminus drush $(ARG_3).live -- cget system.site page.404
	terminus drush $(ARG_3).live -- cget cp_header_and_footer_blocks.header_settings search_page
	@echo '✅ COMPLETE'
	
term_fox_brand_test: ## Terminus brand test: make term_fox_brand_test ascenda dig0030342-baby-and-me-trinidad-tobago
	$(MAKE) term_auth
	terminus drush $(ARG_2).live -- en fox
	
	terminus drush $(ARG_2).live -- fox --input="\
	SET brand TO $(ARG_1);\
	\
	USE node;\
	SELECT nid WHERE field_domain_access = @brand INTO brand_content;\
	TEST COUNT brand_content = 3 check brand content;\
	SELECT id FROM menu_link_content.main WHERE menu_item_domains = @brand INTO data;\
	TEST COUNT count = 1 check main menu;\
	SELECT tid FROM taxonomy_term.brand WHERE machine_name = brand_@brand and status = 1 INTO data;\
	TEST COUNT count = 1 check published brand;\
	\
	QUIT\
	"

term_fox_disable: ## Terminus fox disable
	$(MAKE) term_auth
	
	terminus drush $(ARG_1).live -- pmu fox -y
	
migrate_tax: ## Migrate taxonomy
	$(MAKE) term_auth
	terminus drush $(ARG_1).live -- content:import /sites/default/files/private/scs/$(ARG_2)
	
migrate_node: ## Migrate node
	$(MAKE) term_auth
	terminus drush $(ARG_1).live -- content:import /sites/default/files/private/scs/$(ARG_2)
	
fix_secrets: ## Fix secrets.json file
	printf "%s\n" "get code/web/sites/default/files/private/secrets.json" "bye" | \
	sftp -o Port=2222 $(ARG_1) 
	
	#sed -i 's/"INSTANCE_ENV"[[:space:]]*:[[:space:]]*"[^"]*"/"INSTANCE_ENV": "dev"/' secrets.json
	nano secrets.json

	echo "put secrets.json code/web/sites/default/files/private/secrets.json" "bye" | \
	sftp -o Port=2222 $(ARG_1)
		
	rm secrets.json
	
cravings_conf_sync: ## Sync cravings tools
	rm -f web/modules/custom/np_tools_cravings/config/install/*
	find config -type f \( -name '*craving*' -o -name '*generic_video_local*' \) \
  		-exec cp -f {} web/modules/custom/np_tools_cravings/config/install \;
	find web/modules/custom/np_tools_cravings/config/install -type f \
  		-exec sed -i '1d;/^langcode:/c\langcode: en' {} \;
  		
clone_env_1: ## Clone environment part 1
	@if [ -z "$(filter $(ARG_2),$(VALID_ENVS))" ]; then \
		echo "❌ ENV must be one of: $(VALID_ENVS)"; \
		exit 1; \
	fi

	$(MAKE) term_auth
	
	#terminus backup:create $(ARG_1).live -y
	terminus env:wipe $(ARG_1).$(ARG_2) -y
	terminus env:clone-content $(ARG_1).live $(ARG_2) -y
	terminus drush $(ARG_1).$(ARG_2) -- sql-sanitize --sanitize-password=no -y
	
	$(MAKE) beep
	@echo '✅ Go to https://dev.azure.com/nestle-it/Consumer-Platform/_build?definitionId=7983 for $(ARG_2) $(ARG_1)'
	@echo '✅ NEXT make clone_env_2 $(ARG_1) $(ARG_2)'
	
clone_env_2: ## Clone environment part 2
	@if [ -z "$(filter $(ARG_2),$(VALID_ENVS))" ]; then \
		echo "❌ ENV must be one of: $(VALID_ENVS)"; \
		exit 1; \
	fi

	$(MAKE) term_auth
	
	terminus drush $(ARG_1).$(ARG_2) -- cr
	terminus drush $(ARG_1).$(ARG_2) -- updb -y
	terminus drush $(ARG_1).$(ARG_2) -- cim -y
	terminus drush $(ARG_1).$(ARG_2) -- config:delete shield.settings
	
	$(MAKE) beep
	@echo '✅ Login to https://$(ARG_2)-$(ARG_1).pantheonsite.io/user/login?admin=1 (serhii.klietsov1@kruschecompany.com / Attico123!)'
	@echo '✅ Go to https://$(ARG_2)-$(ARG_1).pantheonsite.io/admin/config/gigya/keys'
	@echo '✅ NEXT make clone_env_3 $(ARG_1) $(ARG_2)'
	
clone_env_3: ## Clone environment part 3
	@if [ -z "$(filter $(ARG_2),$(VALID_ENVS))" ]; then \
		echo "❌ ENV must be one of: $(VALID_ENVS)"; \
		exit 1; \
	fi

	$(MAKE) term_auth
	
	terminus drush $(ARG_1).$(ARG_2) -- cp-domain:set-hostname --url=$(if $(strip $(ARG_3)),$(ARG_3),$(ARG_2)-$(ARG_1).pantheonsite.io) -y
	#terminus drush $(ARG_1).$(ARG_2) -- cron
	
	$(MAKE) beep
	@echo "✅ All done $(ARG_1) $(ARG_2)"
	
set_host: ## Set host
	terminus drush $(ARG_1).dev -- cp-domain:set-hostname --url=dev-$(ARG_1).pantheonsite.io -y
	terminus drush $(ARG_1).test -- cp-domain:set-hostname --url=test-$(ARG_1).pantheonsite.io -y
	
	$(MAKE) beep
	@echo "✅ All done $(ARG_1)"

 
 
