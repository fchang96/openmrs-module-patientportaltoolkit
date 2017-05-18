<script>
    
    
    
    var managePreventiveCareModal_handler = {
        modal : null,
        appointment_id : null,
        concepts : null,
        data_manager: null,
        dropdown_handler : null,
        dropdown_initialized : false,
        defined_relative_orders : [ // note - for best results, only define one relative ordering (as many questions as desired) per concept
            [
                "63ee5099-567e-4b55-936c-c4c8d71d1144",  // systolic
                "02310664-f7bb-477c-a703-0325af4c3f46",  // diastolic
            ],
         ],

        open_modal_for : function(appointment_id){
            this.modal.modal('show');
            this.appointment_id = appointment_id;
            this.open_part('markCompleted'); // hardcoded as markCompleted as no other options are enabled
            this.open_sub_part(); // ensure special requirements for each procedure are accounted for
            this.update_visible_data_for_event();
        },
        
        //////////
        // DOM interactions
        //////////
        open_part : function(which_part){
            valid_parts = ["menu", "markCompleted"];
            if((valid_parts.indexOf(which_part) == -1)){
                console.log("Requested part to open is not valid");
                return;
            }
            this.hide_all_parts();
            //console.log(':  - ' + which_part);
            this.modal.find("."+which_part+"-part").show(); 
            this.modal.find(".all-parts").show(); 
            this.modal.find("."+which_part+"-exclude-part").hide(); 
            
            //if(which_part == "menu") this.update_valid_menu_options();
        },
        open_sub_part : function(){
            var event = this.data_manager.data[this.appointment_id];
            var concept_id = event.concept_id + "";
            this.modal.find("."+concept_id+"-part").show();
            console.log(concept_id);
        },
        update_visible_data_for_event : function(){
            var event = this.data_manager.data[this.appointment_id];
            
            // update title
            this.modal.find(".modal-title").html(event.followProcedureName + " Appointment");
            
            // update modify input defaults to current data
            //this.input.modify.appointment_date.data('datepicker').setValue(event.targetDate);
            
        },
        //update_valid_menu_options : function(){},
        hide_all_parts : function(){
            this.modal.find(".modal-part").hide();
        },
        close_modal : function(){
            this.modal.modal('toggle');
        },
        
        ///////////////
        // Handle Actions
        ///////////////
        trigger_action : function(which_part){
            valid_parts = ["markCompleted"];
            if((valid_parts.indexOf(which_part) == -1)){
                console.log("Requested part to trigger is not valid ( " + which_part + " )");
                return;
            }
            if(which_part == "markCompleted") {
                this.attempt_mark_completed();
            }
        },
        
        attempt_mark_completed : function(){
            console.log(this.data_manager.data);
            var event = this.data_manager.data[this.appointment_id];
            var concept_id = event.concept_id;
            

            //////////////
            // Get question responses 
            /////////////
            var questions = this.concepts[concept_id].questions;
            var question_holder_parent = this.modal.find("."+concept_id+"-part");
            var request_data = []; 
            for (var i = 0; i < questions.length; i++){
                var this_question = questions[i];
                var this_uuid = this_question.uuid;
                var this_datatype = this_question.datatype;
                var this_holder = question_holder_parent.find("#question_"+this_question.uuid);
                var this_response = this.grab_response_from(this_holder, this_datatype);
                
                request_data.push({
                    uuid : this_uuid,
                    datatype : this_datatype, 
                    response : this_response, 
                });
            }
            
            //////////////////////
            // Grab all relevant data
            //////////////////////
            var event_id             = this.appointment_id;
            var person_uuid          = jq("#personUuid").val();
            var formated_target_date = event.formatedTargetDate;
            var concept_id           = concept_id;
            var json_data            = JSON.stringify(request_data);
            
            ////////////
            // Submit request
            ////////////
            jq.get("preventiveCareManageModal/markPreventiveCareCompleted.action", {
                eventId : event_id,
                personUuid : person_uuid,
                formatedTargetDate : formated_target_date,
                conceptId : concept_id,
                jsonData : json_data,
            }, function () {
                console.log("Request Responded");
                location.reload();
            });
        },
        
        grab_response_from : function(question_holder, question_datatype){
            // Grab input element(s)
            var response_holder = question_holder.find(".preventive_care_input");
            
            // parse input elements
            var response = null;
            if(question_datatype == "NM") response = response_holder[0].value;
            if(question_datatype == "DT") response = response_holder[0].value;
            if(question_datatype == "BIT") {
                if(response_holder[0].checked) response = "true";
                if(response_holder[1].checked) response = "false";
            }
            console.log("response: " + response);
            
            return response;
        },
        
        /////////////////////////////////////
        // Initialize concept data and generate input templates
        /////////////////////////////////////
        initialize_concepts : function(){
            //console.log(jq("#personUuid").val());
            var OpenMRSInstance=window.location.href;
            //Load Reminder data, insert reminders into calendar and table
            //console.log(OpenMRSInstance.split("/patientportaltoolkit")[0]+'/ws/patientportaltoolkit/getremindersforpatient/'+ jq("#personUuid").val());
            jq.get(OpenMRSInstance.split("/patientportaltoolkit")[0]+'/ws/patientportaltoolkit/getRelevantPreventiveCareConcepts/'+ jq("#personUuid").val(), function (relevantConcepts) {
                console.log(relevantConcepts);
                // Set datasource for reminder table
                this.setDataSource(relevantConcepts);
            }.bind(this));
        },
        setDataSource : function(relevant_concepts){
            // Store concepts by concept id
            this.concepts = [];
            for(var i = 0; i < relevant_concepts.length; i++){
                var this_concept = relevant_concepts[i];
                this.concepts[this_concept.concept_id] = this_concept;
            }
            
            // Build dom input elements for concept questions
            this.build_input_from_concepts(relevant_concepts);
        },
        
        
        
        
        build_input_from_concepts : function(concepts){
            var holder = this.DOM.markCompleted_concept_holder;
            
            //////////
            // Sort concept questions by predefined orders (this.defined_relative_orders)
            //////////
            concepts = this.sort_concept_questions(concepts); 
            
            //////////
            // Insert each concept into holder
            //////////
            for(var i = 0; i < concepts.length; i++){
                var this_concept = concepts[i];
                
                //var wrapper = document.createElement("div");
                var parent = document.createElement("div");
                parent.className = this_concept.concept_id + "-part modal-part"; // Note: Parent holder can be found by .find("."+contept_id+"-part");
                for(var j = 0; j < this_concept.questions.length; j++){
                    var this_question = this_concept.questions[j];
                    
                    var question = document.createElement("form");
                    question.id = "question_" + this_question.uuid; // Note: Each question can be found by .find("#question_"+question.uuid);, recommended parent.find(...)
                    question.className = "form-inline";
                    
                    var label = document.createElement("label");
                    label.className = "uniform_width_manage_preventive_care_modal_question_label reformatText";
                    label.innerHTML = this_question.name;
                    
                    var input_element_class_name = "preventive_care_input form-control openmrs_concept_datatype_" + this_question.datatype; // datatype part used to instantiate datetime elements 
                    if(this_question.datatype == "BIT"){
                        // Boolean data
                        var input = document.createElement("div");
                        input.className = "radio";
                        boolean_constants = [["true", "Yes"], ["false", "No"]]; // creates two radio buttons, "name" = [0], title = [1]
                        for(var k = 0; k < boolean_constants.length; k++){
                            var these_constants = boolean_constants[k];
                            var boolean = document.createElement("label");
                            boolean.className = "radio-inline";
                            var boolean_input = document.createElement("input");
                            boolean_input.type = "radio";
                            boolean_input.name = "preventive_care_radio";
                            boolean_input.value = these_constants[0];
                            boolean_input.className = input_element_class_name; 
                            boolean.appendChild(boolean_input);
                            boolean.innerHTML += these_constants[1];
                            input.appendChild(boolean);
                        }
                    } else {
                        var input = document.createElement("input");
                        input.type = (this_question.datatype == "NM") ? "number" : "text"; 
                        input.className = input_element_class_name; 
                        if(this_question.datatype == "DM") input.className += " datepicker"
                    }
                    question.appendChild(label);
                    question.appendChild(input);
                    parent.appendChild(question);
                }
                
                // append to content holder
                holder.append(parent);
                
            }
            
            //////////
            // initialize all date time inputs
            //////////
            var datepicker_elements = this.modal.find(".openmrs_concept_datatype_DT");
            //console.log(datepicker_elements);
            for(var i = 0; i < datepicker_elements.length; i++){
                var element = this.modal.find(datepicker_elements[i]);
                element.datepicker({ format: 'mm/dd/yyyy' }).on('changeDate', function(){ this.data('datepicker').hide() }.bind(element));
            }
        },
        
        sort_concept_questions : function(concepts){
            ////////////
            // For each concept, check the question list, and ensure that the order of the questions matches the defined relative orders
            //      implementation - determine if a question can be added to the list based on the relative orders defined and the elements currently in front of it in the list. 
            //                      Keep a queue for those who cant be yet added and recheck the queued elements each time an element is added
            ////////////
            for(var i = 0; i < concepts.length; i++){
                var these_questions = concepts[i].questions;
                var final_questions = [];
                var questions_queue = [];
                for(var j = 0; j < these_questions.length; j++){
                    var this_question = these_questions[j];
                    var this_uuid = this_question.uuid;
                    
                    // determine whether this element can be added to list
                        // if the element is defined in relative orderings, ensure that all elements before it in the orderings exist in the list before adding
                        // if the elements required to be before it dont exist in the list yet, then put this element in a queue to be rechecked after another element is added
                    var can_add_to_list = this.can_this_question_uuid_be_added_to_list(this_uuid, final_questions);
                    if(can_add_to_list){
                        final_questions.push(this_question);
                    } else{
                        questions_queue.push(this_question);
                    }
                    //console.log("Now system is at (for i = " + i + ") ....");
                    //console.log(JSON.parse(JSON.stringify(final_questions)));
                    //console.log(JSON.parse(JSON.stringify(questions_queue)));
                    
                    
                    // if something was added to the list, recheck all the queued elements (keep checking if a queued element was added, too)
                    if(can_add_to_list){
                        var one_was_just_added = true;
                        while(one_was_just_added){
                            one_was_just_added = false;
                            var first_addable_queued_question = this.find_first_addable_queued_question(questions_queue, final_questions);
                            if(first_addable_queued_question == false) continue; // if none can be found, exit the loop
                            one_was_just_added = true;
                            final_questions.push(first_addable_queued_question); // add item to questions list
                            questions_queue = questions_queue.filter(function(element) { return element !== first_addable_queued_question}); // remove item from queue
                        }
                    }
                }
                concepts[i].questions = final_questions;
            }
            return concepts;
        },
        can_this_question_uuid_be_added_to_list : function(this_uuid, current_list){
            var defined_relative_orders = this.defined_relative_orders;
            var relevant_question_uuid_list = [].concat.apply([], defined_relative_orders); // flatten list of lists
            var uuid_in_current_list = current_list.map(function(a) {return a.uuid;});
            var can_add_to_list = true;
            if(relevant_question_uuid_list.includes(this_uuid)){
                // for each relative order, ensure that either it is not included in the ordering or that all uuid defined to come before this uuid have been included in final_questions list
                for(var i = 0; i < defined_relative_orders.length; i++){
                    if(!can_add_to_list) break; // if it has been found that it can not be added, dont continue to assess
                    var this_relative_ordering = defined_relative_orders[i];
                    if(!this_relative_ordering.includes(this_uuid)) continue; // uuid is not included in this ordering
                    // for each element before this uuid in the ordering,
                    for(var j = 0; j < this_relative_ordering.indexOf(this_uuid); j++){
                        // ensure it is in the list, if it is not, break - you can not add this element to the list
                        var uuid_to_be_added_before_this_uuid = this_relative_ordering[j]; 
                        if(!uuid_in_current_list.includes(uuid_to_be_added_before_this_uuid)){
                            can_add_to_list = false;
                            break;
                        }  
                    } 
                }
            }
            return can_add_to_list;
        },
        find_first_addable_queued_question : function(queued_list, current_list){
            for(var i = 0; i < queued_list.length; i++){
                var queued_question = queued_list[i];
                var queued_uuid = queued_question.uuid;
                var can_add_this_queued_question_to_list = this.can_this_question_uuid_be_added_to_list(queued_uuid, current_list);
                if(can_add_this_queued_question_to_list){
                    return queued_question;
                }
            }
            return false;
        },
        
    }
    
    
    
    /////////////////////
    // Initialize Manage Event Modal Settings
    //////////////////////
    window.addEventListener("load", function(){
        var the_modal = jq('#managePreventiveCare-modal');
        
        // Define modal_handler values
        managePreventiveCareModal_handler.modal = the_modal;
        managePreventiveCareModal_handler.data_manager = preventive_data_manager;
        managePreventiveCareModal_handler.buttons = {
            menu : {
               //markCompleted : document.getElementById('managePreventive_menu_markCompleted'),
            },
            action : {
                markCompleted : document.getElementById('managePreventive_button_markCompleted'),
            },
            back : the_modal.find("#back_button"),
            cancel : the_modal.find(".modal_cancel_button"),
        }
        /*
        managePreventiveCareModal_handler.input = {
            markCompleted : {
                completed_date : the_modal.find('#completed_date'),  
                doctor_name : the_modal.find('#doctor_name'),
                comments : the_modal.find('#comments'),
            },
        }
        */
 
        // Initialize menu buttons
        var button_keys = Object.keys(managePreventiveCareModal_handler.buttons.menu);
        for (var i = 0; i<button_keys.length; i++){
            var this_key = button_keys[i]; 
            (function(key_by_value){ // If not wrapped in annon function all buttons.menu items open same `part`
                managePreventiveCareModal_handler.buttons.menu[key_by_value].onclick = function(){ managePreventiveCareModal_handler.open_part(key_by_value) };
            })(this_key);
        }
        
        // Initialize action buttons
        var button_keys = Object.keys(managePreventiveCareModal_handler.buttons.action);
        for (var i = 0; i<button_keys.length; i++){
            var this_key = button_keys[i]; 
            (function(key_by_value){ // If not wrapped in annon function all buttons.menu items open same `part`
                managePreventiveCareModal_handler.buttons.action[key_by_value].onclick = function(){
                    managePreventiveCareModal_handler.trigger_action(key_by_value)
                };
            })(this_key);
        }
        
        // Initialize back button
        managePreventiveCareModal_handler.buttons.back.on( "click", function(){
            managePreventiveCareModal_handler.open_menu_again();
        });
        
        // initialize cancel buttons
        managePreventiveCareModal_handler.buttons.cancel.on( "click", function(){
            managePreventiveCareModal_handler.close_modal();
        });
        
        
        // Load concepts from database w/ async request, build the input forms dynamically.
        managePreventiveCareModal_handler.initialize_concepts(); 
        managePreventiveCareModal_handler.DOM = {
            markCompleted_concept_holder : the_modal.find("#markCompleted_concept_holder"),
        }
        /*
        // Initialize datepicker inputs
        var datepicker_ids = ["#influenzaDate", "#pneumococcalDate", "#cholesterolDate", "#bpDate", "#hivDate", "#mammographyDate", "#cervicalDate" ];
        //var datepicker_elements = [];
        //datepicker_elements.push(managePreventiveCareModal_handler.input.markCompleted.completed_date);
        for(var i = 0; i < datepicker_ids.length; i++){
            var element = jq(datepicker_ids[i]);
            element.datepicker({ format: 'mm/dd/yyyy' }).on('changeDate', function(){ this.data('datepicker').hide() }.bind(element));
        }
        */
    });
  
    
    
    
</script>
<style>
.uniform_width_manage_preventive_care_modal_question_label {
    width:300px;   
}
</style>
<div class="modal fade modal-wide"  id="managePreventiveCare-modal" role="dialog" aria-labelledby="preventiveCareLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close modal_cancel_button" aria-label="Close"><span
                        aria-hidden="true">&times;</span></button>
                <h4 class="modal-title"> Modal Title </h4>
            </div>
            <div class="modal-body">
                <div id = "markCompleted_concept_holder" class = 'markCompleted-part modal-part'>
                   
                </div>
            </div>
            
            <div class="modal-footer" style = 'z-index:10;'>
                <div class="button-div pull-left  ">
                    <!-- commented out because there is no menu yet 
                    <button type="button" class="btn btn-default all-parts menu-exclude-part add_new-exclude-part" id = 'back_button'>Back</button>
                    -->
                </div>
                <div class="button-div pull-right ">
                    <button type="button" class="btn btn-default modal_cancel_button modal-part all-parts">Cancel</button>
                    <button type="button" class="btn btn-primary modal-part markCompleted-part" id="managePreventive_button_markCompleted"> Mark Completed </button>
                </div>
            </div>
        </div>
    </div>
</div>