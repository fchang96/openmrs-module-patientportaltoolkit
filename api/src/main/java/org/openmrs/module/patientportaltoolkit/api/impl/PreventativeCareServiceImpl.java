/**
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/. OpenMRS is also distributed under
 * the terms of the Healthcare Disclaimer located at http://openmrs.org/license.
 *
 * Copyright (C) OpenMRS Inc. OpenMRS is a registered trademark and the OpenMRS
 * graphic logo is a trademark of OpenMRS Inc.
 */
package org.openmrs.module.patientportaltoolkit.api.impl;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.joda.time.LocalDate;
import org.openmrs.Concept;
import org.openmrs.Patient;
import org.openmrs.api.context.Context;
import org.openmrs.api.impl.BaseOpenmrsService;
import org.openmrs.module.patientportaltoolkit.PreventativeCareEvent;
import org.openmrs.module.patientportaltoolkit.PreventiveCareGuideline;
import org.openmrs.module.patientportaltoolkit.PreventiveCareGuidelineInterval;
import org.openmrs.module.patientportaltoolkit.api.PreventativeCareService;
import org.openmrs.module.patientportaltoolkit.api.db.PreventativeCareDAO;
import org.openmrs.Encounter;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Calendar;

/**
 * Created by maurya on 11/30/16.
 */
public class PreventativeCareServiceImpl extends BaseOpenmrsService implements PreventativeCareService {
    protected PreventativeCareDAO dao;

    protected final Log log = LogFactory.getLog(this.getClass());

    /**
     * @return the dao
     */
    public PreventativeCareDAO getDao() {
        return dao;
    }

    /**
     * @param dao the dao to set
     */
    public void setDao(PreventativeCareDAO dao) {
        this.dao = dao;
    }


    @Override
    public PreventativeCareEvent getEventById(String Id) {
        // If id is not a valid integer, return null - like would be returned if no reminders with a valid integer id were found.
        try {
            return dao.getPreventativeCareEvent(Integer.parseInt(Id));
        } catch (NumberFormatException e) {
            return null;
        }
    }
    
    @Override
    public PreventativeCareEvent getEventByIdOrGuidelineData(String databaseId, Patient patient, String conceptId, Date targetDate) {
        PreventativeCareEvent event = null;
        // attempt to get reminder by id
        event = getEventById(databaseId);
        if(event == null){
            //System.out.println("Event with that id is not found in database. Time to generate it by guideline data!"
            Concept followUpConcept = Context.getConceptService().getConcept(conceptId);
            event = generateEventFromGuidelineData(patient, followUpConcept, targetDate); 
        }
        return event;
    }
    

    @Override
    public List<PreventativeCareEvent> getAllPreventativeCareEventByPatient(Patient patient) {
        List<PreventativeCareEvent> preventiveEvents = new ArrayList<>();
        List<PreventativeCareEvent> databasePreventiveEvents = new ArrayList<>();
        
        // Get all events from database
        databasePreventiveEvents = dao.getAllPreventativeCareEventsByPatient(patient);
        preventiveEvents.addAll(databasePreventiveEvents);

        // Get all events from guidelines
        Date dateOfJoin = patient.getDateCreated();
        LocalDate modifiableDate = null;
        Date targetDate = null;
        for (PreventiveCareGuideline g:  getPreventativeCareGuideline(patient)){ // For each guideline
            for (PreventiveCareGuidelineInterval gi: g.getPcgguidelineIntervalSet()){ // and for each guideline's set of intervals (e.g., check up in 6mo, 12mo, and 24mo)
                modifiableDate = new LocalDate(dateOfJoin);
                targetDate = modifiableDate.plusMonths(gi.getIntervalLength()).toDate();
                targetDate = enforceConceptSpecificTargetDateRequirements(targetDate, g.getFollowupProcedure()); // enforces, for example, that influenza target dates fall between oct and march
                
                // If this reminder, with same target date, was already found in database recorded reminders : don't duplicate it. Just continue. 
                if(findEventByConceptAndDate(databasePreventiveEvents,g.getFollowupProcedure(),targetDate) != null)
                    continue;
                
                // Create, on the fly, a new event with the followup procedure and target date required by guidelines.
                PreventativeCareEvent event = generateEventFromGuidelineData(patient, g.getFollowupProcedure(), targetDate);
                preventiveEvents.add(event); 
            }
        }
        
        
        // Now that guidelines are generated, remove all events from list which have a status of -1
        List<PreventativeCareEvent> valid_events = new ArrayList<>();
        for (PreventativeCareEvent event:  preventiveEvents) {
            if(event.getStatus() != -1) valid_events.add(event);
        }
        
        
       return valid_events;
    }
    
    /*
    * Used to enforce date requirements on preventive care events
    */
    Date enforceConceptSpecificTargetDateRequirements(Date targetDate, Concept targetConcept){
        Calendar cal = Calendar.getInstance();
        cal.setTime(targetDate);
        int month = cal.get(Calendar.MONTH);
        
        // Enforce that, if event is influenza vacination, the date falls between oct and march
        if (targetConcept.getConceptId() == 162938){ 
            if(!(month >= (10-1) || month <= (3-1))){ // Ensure that date is between oct and march. Note, minus 1 due to jan = 0
                //System.out.println("chaning date!");
                cal.set(Calendar.MONTH, Calendar.OCTOBER);
                cal.set(Calendar.DAY_OF_MONTH, 1);
                //System.out.println("Changing date to...");
                targetDate = cal.getTime();
                //System.out.println(targetDate);
            }
        }
        
        return targetDate;
    }
    
    /*
    * Used to determine if an event with the same targetDate and targetConcept already exists from a list of events
    */
    PreventativeCareEvent findEventByConceptAndDate (List<PreventativeCareEvent> searchList, Concept targetConcept, Date targetDate){
        PreventativeCareEvent event = null;
        for(PreventativeCareEvent e:searchList) {
            if(e.getTargetDate() == null)
                continue;
            if(e.getFollowProcedure().equals(targetConcept) && e.getOrigTargetDate().equals(targetDate)){
                event=e;
            }
        }
        return event;
    }
    
    
    
    @Override
    public PreventativeCareEvent generateEventFromGuidelineData(Patient patient, String conceptId, Date targetDate){
            Concept followUpConcept = Context.getConceptService().getConcept(conceptId);
            return generateEventFromGuidelineData(patient, followUpConcept, targetDate); 
    }
    
    @Override
    public PreventativeCareEvent generateEventFromGuidelineData(Patient patient, Concept followupConcept, Date targetDate){
        PreventativeCareEvent event = new PreventativeCareEvent();
        event.setPatient(patient);
        event.setFollowProcedure(followupConcept);
        event.setTargetDate(targetDate);
        event.setOrigTargetDate(targetDate);
        event.setStatus(0);
        return event;
    }
    
    
    
    @Override
    public List<PreventativeCareEvent> getPreventativeCareEventsCompleted(Patient patient) {
        return null;
    }


    @Override
    public PreventativeCareEvent savePreventativeCareEvent(PreventativeCareEvent preventativeCareEvent) {
        return null;
    }

    @Override
    public PreventativeCareEvent markCompletedEvent(PreventativeCareEvent event, Date markCompleteDate, Encounter relevantEncounter) {
        // Takes an event object, marks it completed, and saves it.
        //System.out.println("Marking event completed ");
        Date today = new Date();
        event.setCompleteDate(markCompleteDate);
        event.setResponseDate(today);
        event.setStatus(1);
        event.setResponseUser(Context.getAuthenticatedUser());
        event.setEncounterUuid(relevantEncounter.getUuid());
        return dao.savePreventativeCareEvent(event);
    }
    
    @Override
    public PreventativeCareEvent updateAssociatedEncounter(PreventativeCareEvent event, Encounter newEncounter) {
        // associate new encounter 
        event.setEncounterUuid(newEncounter.getUuid());
        //event.setModifiedDate(today);
        return dao.savePreventativeCareEvent(event);
    }
    
    
    
    @Override
    public PreventativeCareEvent updateCompletedDate(PreventativeCareEvent event, Date completedDate) {
        // Takes a reminder object, marks it completed, and saves it.
        Date today = new Date();
        event.setCompleteDate(completedDate);
        //event.setModifiedDate(today);
        return dao.savePreventativeCareEvent(event);
    }
    
    @Override
    public PreventativeCareEvent modifyTargetDate(PreventativeCareEvent event, Date newTargetDate) {
        // Takes a reminder object, marks it completed, and saves it.
        Date today = new Date();
        event.setTargetDate(newTargetDate);
        //event.setModifiedDate(today);
        return dao.savePreventativeCareEvent(event);
    }
    
    
    @Override
    public PreventativeCareEvent removeEvent(PreventativeCareEvent event) {
        // Takes a reminder object, marks it completed, and saves it.
        Date today = new Date();
        event.setStatus(-1);
        //event.setModifiedDate(today);
        return dao.savePreventativeCareEvent(event);
    }
    
    
    @Override
    public PreventativeCareEvent addEvent(PreventativeCareEvent event) {
        // Takes an event object and saves it into database
        Date today = new Date();
        event.setStatus(0);
        //event.setModifiedDate(today);
        return dao.savePreventativeCareEvent(event);
    }


    @Override
    public PreventativeCareEvent markScheduledPreventativeCareEvent(String PreventativeCareEventId, Date date) {
        return null;
    }

    @Override
    public List<PreventiveCareGuideline> getPreventativeCareGuideline(Patient patient) {
        List<PreventiveCareGuideline> totalPreventiveCareGuidelines = dao.getAllPreventativeCareGuidelines();
        //Screening Mammography
        if (patient.getGender().equals("M") || (patient.getGender().equals("F") && patient.getAge()<40)) {
            totalPreventiveCareGuidelines.remove(dao.getPreventativeCareGuidelinebyID(5));
        }
        //Cervical Cancer Screening
        if (patient.getGender().equals("M") || (patient.getGender().equals("F") && (patient.getAge()<21 || patient.getAge()>65))) {
            totalPreventiveCareGuidelines.remove(dao.getPreventativeCareGuidelinebyID(6));
        }
        //Cholesterol Screening
        if ((patient.getGender().equals("F") && patient.getAge()<45) || (patient.getGender().equals("M") && patient.getAge()<35)) {
            totalPreventiveCareGuidelines.remove(dao.getPreventativeCareGuidelinebyID(7));
        }

        return totalPreventiveCareGuidelines;
    }


    @Override
    public void savePreventiveCareGuideLine(PreventiveCareGuideline pcg) {
        dao.savePreventiveCareGuideLine(pcg);
    }

    public List<PreventiveCareGuideline> getPreventiveCareGuideLine()
    {
      return dao.getPreventiveCareGuideLine();
    }


    public PreventiveCareGuideline getPreventiveCareGuideLine(int id)
    {
        return dao.getPreventiveCareGuideLine(id);
    }

    @Override
    public void deletePreventiveCareGuideLine(PreventiveCareGuideline pcg) {
        dao.deletePreventiveCareGuideLine(pcg);
    }

    @Override
    public void savePreventiveCareGuidelineInterval(PreventiveCareGuidelineInterval pcg_interval) {
        dao.savePreventiveCareGuidelineInterval(pcg_interval);
    }

    @Override
    public List<PreventiveCareGuidelineInterval> getPreventiveCareGuidelineInterval() {
        return dao.getPreventiveCareGuidelineInterval();
    }

    @Override
    public List<PreventiveCareGuidelineInterval> getPreventiveCareGuidelineInterval(PreventiveCareGuideline pcg) {
        return dao.getPreventiveCareGuidelineInterval(pcg);
    }

    @Override
    public void deletePreventiveCareGuidelineInterval(PreventiveCareGuidelineInterval pcg_interval) {
        dao.deletePreventiveCareGuidelineInterval(pcg_interval);
    }

}
